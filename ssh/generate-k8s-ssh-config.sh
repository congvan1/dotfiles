#!/usr/bin/env bash

# Script to generate SSH config entries from Kubernetes nodes across multiple contexts
# Usage: ./generate-k8s-ssh-config.sh

set -euo pipefail

# Configuration
SSH_KEY_DIR="${SSH_KEY_DIR:-$HOME/Downloads/VNG/ssh_key}"
OUTPUT_FILE="${1:-k8s-ssh-config.txt}"

# Associative array mapping context to SSH key path
declare -A CONTEXT_SSH_KEYS=(
    ["vng-dev"]="$SSH_KEY_DIR/sshkey-vtvcab-dev-all.pem"
    ["vng-stg"]="$SSH_KEY_DIR/sshkey-vtvcab-vks-stg-002.pem"
    ["vng-prd"]="$SSH_KEY_DIR/sshkey-vtvcab-vks-prod-001.pem"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔍 Generating SSH config from Kubernetes contexts..."
echo "📁 SSH Key Directory: $SSH_KEY_DIR"
echo ""

# Clear output file
> "${OUTPUT_FILE}"
declare -A alias_indices

# Function to process each context
process_context() {
    local context=$1
    
    echo -e "${YELLOW}Processing context: $context${NC}"
    
    # Switch to context
    if ! kubectl config use-context "$context" &>/dev/null; then
        echo -e "${RED}✗ Failed to switch to context: $context${NC}"
        return 1
    fi
    
    # Get SSH key for this context from the associative array
    local ssh_key="${CONTEXT_SSH_KEYS[$context]}"
    if [[ -z "$ssh_key" || ! -f "$ssh_key" ]]; then
        echo -e "${RED}✗ SSH key not found for $context: $ssh_key${NC}"
        return 1
    fi
    echo -e "${GREEN}✓ Using SSH key: $(basename "$ssh_key")${NC}"
    
    # Get nodes and their IPs
    echo "  Fetching nodes..."
    local nodes=$(kubectl get nodes -o json 2>/dev/null)
    
    if [[ -z "$nodes" ]]; then
        echo -e "${RED}✗ No nodes found in $context${NC}"
        return 1
    fi
    
    # Parse nodes and generate SSH config
    local node_count=0
    echo "" >> "$OUTPUT_FILE"

    
    # Extract node names and IPs
    while IFS=$'\t' read -r node_name internal_ip external_ip; do
        # Use external IP if available, otherwise internal
        local ip="${external_ip:-$internal_ip}"
        
        if [[ -n "$ip" && "$ip" != "null" && "$ip" != "" ]]; then
            # Generate SSH config entry with friendly alias
            tier="${context#vng-}"
            IFS='-' read -ra parts <<< "${node_name}"
            type="${parts[0]}"
            # sub_type may be composed of two parts (e.g., flink-session) if present
            if [[ ${#parts[@]} -ge 7 ]]; then
                sub_type="${parts[5]}-${parts[6]}"
            else
                sub_type="${parts[5]}"
            fi
            
            # Build the group key and get/increment the index for this group
            group_key="${tier}-${type}-${sub_type}"
            if [[ ! -v alias_indices[$group_key] ]]; then
                alias_indices[$group_key]=1
            fi
            index=$(printf "%03d" ${alias_indices[$group_key]})
            ((alias_indices[$group_key]++))
            
            alias_name="${group_key}-${index}"

            cat >> "$OUTPUT_FILE" << EOF

Host ${alias_name}
    HostName ${ip}
    User stackops
    Port 234
    IdentityFile ${ssh_key}
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF
            
            ((node_count++))
            echo -e "  ${GREEN}✓${NC} $node_name: $ip"
        fi
    done < <(echo "$nodes" | jq -r '.items[] | [
        .metadata.name,
        (.status.addresses[] | select(.type=="InternalIP") | .address),
        ((.status.addresses[] | select(.type=="ExternalIP") | .address) // "")
    ] | @tsv')
    
    echo -e "${GREEN}✓ Processed $node_count nodes from $context${NC}"
    echo ""
}

# Main execution
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

for context in "${!CONTEXT_SSH_KEYS[@]}"; do
    process_context "$context" || true
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}✓ SSH config generated: $OUTPUT_FILE${NC}"
# Backup existing SSH config
backup_file="${HOME}/.ssh/config.backup.$(date +%Y%m%d%H%M%S)"
if [ -f "${HOME}/.ssh/config" ]; then
    cp "${HOME}/.ssh/config" "$backup_file"
    echo -e "${GREEN}✓ Backup created at $backup_file${NC}"
fi

# Append generated config to SSH config
cat "$OUTPUT_FILE" >> "${HOME}/.ssh/config"
echo -e "${GREEN}✓ Appended $OUTPUT_FILE to ~/.ssh/config${NC}"
rm "$OUTPUT_FILE"
