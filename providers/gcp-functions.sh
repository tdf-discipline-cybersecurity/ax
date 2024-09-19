#!/bin/bash

AXIOM_PATH="$HOME/.axiom"

###################################################################
#  Create one instance at a time
#
#  Needed for axiom-init
create_instance() {
    name="$1"
    image_id="$2"
    machine_type="$3"
    region="$4"
    key="$(cat "$AXIOM_PATH/axiom.json" | jq -r '.service_account_key')"
    zone="$(cat "$AXIOM_PATH/axiom.json" | jq -r '.zone')"
    gcloud auth activate-service-account --key-file="$key"

    gcloud compute instances create "$name" \
        --image "$image_id" \
        --machine-type "$machine_type" \
        --zone "$zone" \
        --tags "axiom-ssh"
}

###################################################################
# Delete instance, if the second argument is set to "true", will not prompt
# Used by axiom-rm
#
delete_instance() {
    name="$1"
    force="$2"
    if [ "$force" == "true" ]; then
        gcloud compute instances delete "$name" --quiet
    else
        gcloud compute instances delete "$name"
    fi
}

###################################################################
# Instances functions
# Used by many functions in this file
instances() {
    gcloud compute instances list --format=json
}

# Takes one argument, name of instance, returns raw IP address
# Used by axiom-ls axiom-init
instance_ip() {
    name="$1"
    instances | jq -r ".[]? | select(.name==\"$name\") | .networkInterfaces[0].accessConfigs[0].natIP"
}

# Used by axiom-select axiom-ls
instance_list() {
    instances | jq -r '.[].name'
}

# Used by axiom-ls
instance_pretty() {
    data=$(instances)

    # Number of instances
    instances_count=$(echo $data | jq -r '.[] | .name' | wc -l)

    totalPrice=0
    header="Instance,External IP,Internal IP,Zone,Machine Type,Status"

    fields=".[] | [.name, .networkInterfaces[0].accessConfigs[0].natIP, .networkInterfaces[0].networkIP, .zone, .machineType, .status] | @csv"
    data=$(echo $data | jq -r "$fields")
    totals="_,_,_,Instances,$instances_count"

    (echo "$header" && echo "$data" && echo "$totals") | sed 's/"//g' | column -t -s,
}

###################################################################
#  Dynamically generates axiom's SSH config based on your cloud inventory
#  Choose between generating the sshconfig using private IP details, public IP details, or optionally lock
#  Used for axiom-exec axiom-fleet axiom-ssh
#
generate_sshconfig() {
    accounts=$(ls -l "$AXIOM_PATH/accounts/" | grep "json" | grep -v 'total ' | awk '{ print $9 }' | sed 's/\.json//g')
    current=$(readlink -f "$AXIOM_PATH/axiom.json" | rev | cut -d / -f 1 | rev | cut -d . -f 1) >/dev/null 2>&1
    sshnew="$AXIOM_PATH/.sshconfig.new$RANDOM"
    instances_data=$(instances)
    echo -n "" > $sshnew
    echo -e "\tServerAliveInterval 60\n" >> $sshnew
    sshkey="$(cat "$AXIOM_PATH/axiom.json" | jq -r '.sshkey')"
    echo -e "IdentityFile $HOME/.ssh/$sshkey" >> $sshnew
    generate_sshconfig="$(cat "$AXIOM_PATH/axiom.json" | jq -r '.generate_sshconfig')"

    if [[ "$generate_sshconfig" == "private" ]]; then
        echo -e "Warning: Generating SSH config for private IP addresses"
        for name in $(echo "$instances_data" | jq -r '.[].name'); do
            ip=$(echo "$instances_data" | jq -r ".[] | select(.name==\"$name\") | .networkInterfaces[0].networkIP")
            if [[ -n "$ip" ]]; then
                echo -e "Host $name\n\tHostName $ip\n\tUser op\n\tPort 2266\n" >> $sshnew
            fi
        done
        mv $sshnew $AXIOM_PATH/.sshconfig
    elif [[ "$generate_sshconfig" == "cache" ]]; then
        echo -e "Warning: SSH config is cached, no new generation"
    else
        for name in $(echo "$instances_data" | jq -r '.[].name'); do
            ip=$(echo "$instances_data" | jq -r ".[] | select(.name==\"$name\") | .networkInterfaces[0].accessConfigs[0].natIP")
            if [[ -n "$ip" ]]; then
                echo -e "Host $name\n\tHostName $ip\n\tUser op\n\tPort 2266\n" >> $sshnew
            fi
        done
        mv $sshnew $AXIOM_PATH/.sshconfig
    fi
}

###################################################################
# Query instances
# Used by axiom-ls axiom-select axiom-fleet axiom-rm axiom-power
#
query_instances() {
    instances_data=$(instances)
    selected=""

    for var in "$@"; do
        if [[ "$var" =~ "*" ]]; then
            var=$(echo "$var" | sed 's/*/.*/g')
            selected="$selected $(echo $instances_data | jq -r '.[].name' | grep "$var")"
        else
            if [[ $query ]]; then
                query="$query\|$var"
            else
                query="$var"
            fi
        fi
    done

    if [[ "$query" ]]; then
        selected="$selected $(echo $instances_data | jq -r '.[].name' | grep -w "$query")"
    else
        if [[ ! "$selected" ]]; then
            echo -e "${Red}No instance supplied, use * if you want to delete all instances...${Color_Off}"
            exit
        fi
    fi

    selected=$(echo "$selected" | tr ' ' '\n' | sort -u)
    echo -n $selected
}

###################################################################
#
# used by axiom-fleet axiom-init
get_image_id() {
    query="$1"
    images=$(gcloud compute images list --no-standard-images --format=json)
    id=$(echo "$images" | jq -r ".[] | select(((.description==\"$query\") or (.name==\"$query\")) and (.architecture==\"X86_64\")) | .id")
    # Return the image ID
    echo $id
}


###################################################################
# Manage snapshots (updated to manage images, keeping function names the same)
# Used by axiom-images and axiom-backup
#
snapshots() {
    gcloud compute images list --no-standard-images --format=json
}

get_snapshots() {
    gcloud compute images list --no-standard-images
}

delete_snapshot() {
    image_name="$1"
    gcloud compute images delete "$image_name" --quiet
}

create_snapshot() {
    instance_name="$1"
    image_name="$2"
    gcloud compute images create "$image_name" \
        --source-disk="$(instance_disk $instance_name)" \
        --source-disk-zone="$(instance_zone $instance_name)"
}

###################################################################
# Get data about regions
# Used by axiom-regions
list_regions() {
    gcloud compute regions list
}

regions() {
    gcloud compute regions list --format=json | jq -r '.[].name'
}

###################################################################
# Manage power state of instances
# Used for axiom-power
#
poweron() {
    instance_name="$1"
    gcloud compute instances start "$instance_name"
}

poweroff() {
    instance_name="$1"
    gcloud compute instances stop "$instance_name"
}

reboot() {
    instance_name="$1"
    gcloud compute instances reset "$instance_name"
}

instance_disk() {
    instance_name="$1"
    gcloud compute instances describe "$instance_name" --format="value(disks[0].source)"
}

###################################################################
# List available instance sizes (machine types)
# Used by ax sizes
#
sizes_list() {
    gcloud compute machine-types list --format="table(name, zone, guestCpus, memoryMb)"
}
