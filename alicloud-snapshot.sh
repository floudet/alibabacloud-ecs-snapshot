#!/usr/bin/env bash
export PATH=$PATH:/usr/local/bin/:/usr/bin




###############################
##                           ##
## INITIATE SCRIPT FUNCTIONS ##
##                           ##
##  FUNCTIONS ARE EXECUTED   ##
##   AT BOTTOM OF SCRIPT     ##
##                           ##
###############################


#
# DOCUMENTS ARGUMENTS
#

usage() {
    echo -e "\nUsage: $0 [-q <quota>] [-i <instance_name>] [-f <filter_string>]" 1>&2
    echo -e "\nOptions:\n"
    echo -e "    -q    Snapshot quota. ECS Snapshot 2.0 specifications: 64 snapshots max for each" 
    echo -e "          disk."
    echo -e "          Default if not set: 64 [OPTIONAL]"
    echo -e "    -i    Instance name to create backups for. If empty, makes backup for the calling"
    echo -e "          host."
    echo -e "    -f    Exclude Disks whose name contain this specified string."
    echo -e "\n"
    exit 1
}


#
# GETS SCRIPT OPTIONS AND SETS GLOBAL VAR SNAPSHOT_QUOTA
#

setScriptOptions()
{
    while getopts ":q:i:f:" o; do
        case "${o}" in
            q)
                opt_q=${OPTARG}
                ;;
            i)
                opt_i=${OPTARG}
                ;;
            f)
                opt_f=${OPTARG}
                ;;
            *)
                usage
                ;;
        esac
    done
    shift $((OPTIND-1))

    if [[ -n $opt_q ]];then
        SNAPSHOT_QUOTA=$opt_q
    else
        SNAPSHOT_QUOTA=64
    fi

    if [[ $SNAPSHOT_QUOTA -gt 64 ]];then
      echo "ECS Snapshot 2.0 specifications: max 64 snapshots for each disk."
      SNAPSHOT_QUOTA=64
    fi

    if [[ -n $opt_i ]];then
        OPT_INSTANCE_NAME=$opt_i
    else
        OPT_INSTANCE_NAME=""
    fi

    if [[ -n $opt_f ]];then
        OPT_FILTER=$opt_f
    else
        OPT_FILTER=""
    fi
}


#
# RETURNS INSTANCE NAME
#

getInstanceName()
{
    if [[ -z "$OPT_INSTANCE_NAME" ]];then
        # get the name for this vm
        local instance_name=$(/bin/hostname)

        echo ${instance_name}
    else
        echo $OPT_INSTANCE_NAME
    fi
}


#
# RETURNS INSTANCE ID
#

getInstanceId()
{
     instance_id=$(aliyun ecs DescribeInstances --InstanceName $(getInstanceName) | egrep -Eow 'InstanceId":"([^"]*)"' | cut -d":" -f 2 | tr -d '"')

     echo ${instance_id}
}


#
# RETURNS INSTANCE ZONE
#

getInstanceRegion()
{
     instance_region=$(aliyun ecs DescribeInstances --InstanceName $(getInstanceName) | egrep -Eow 'RegionId":"([^"]*)"' | cut -d":" -f 2 | tr -d '"')

     echo ${instance_region}
}


#
# RETURNS LIST OF DEVICES
#

getDeviceList()
{
    device_list=$(aliyun ecs DescribeDisks --RegionId $(getInstanceRegion) --InstanceId $(getInstanceId) | egrep -Eow 'DiskId":"([^"]*)"' | cut -d":" -f 2 | tr -d '"')

    echo "$device_list"
}


#
# RETURNS DEVICE NAME
#
# input: ${DEVICE_ID}
#

getDeviceName()
{
    json_device_id="[\"$1\"]"

    device_name=$(aliyun ecs DescribeDisks --RegionId $(getInstanceRegion) --DiskIds $json_device_id | egrep -Eow 'DiskName":"([^"]*)"' | cut -d":" -f 2 | tr -d '"')

    echo ${device_name}
}

#
# RETURNS DEVICE TYPE
#
# input: ${DEVICE_ID}
#

getDeviceType()
{
    json_device_id="[\"$1\"]"
    
    device_type=$(aliyun ecs DescribeDisks --RegionId $(getInstanceRegion) --DiskIds $json_device_id | egrep -Eow '\"Type":"([^"]*)"' | cut -d":" -f 2 | tr -d '"')

    echo ${device_type}
}


#
# RETURNS DEVICE TYPE
#
# input: ${DEVICE_ID}
#

getDeviceFile()
{
    json_device_id="[\"$1\"]"

    device_file=$(aliyun ecs DescribeDisks --RegionId $(getInstanceRegion) --DiskIds $json_device_id | egrep -Eow 'Device":"([^"]*)"' | cut -d':' -f2 | tr -d ',' | sed -e 's/"//g' -e 's;/dev/;;')

    echo ${device_file}
}


#
# RETURNS SNAPSHOT NAME
#

createSnapshotName()
{
    # aes (Alicloud ECS Snapshot)
    local name="aes-$1-$2-$3-$4" 

    echo -e ${name}
}


#
# CREATES SNAPSHOT AND RETURNS OUTPUT
#
# input: ${DEVICE_ID}, ${SNAPSHOT_NAME}
#

createSnapshot()
{
    echo -e "$(aliyun ecs CreateSnapshot --DiskId $1 --SnapshotName $2)"
}


#
# GETS LIST OF SNAPSHOTS AND SETS GLOBAL ARRAY $SNAPSHOTS
#
# input: ${DEVICE_ID}
#

getSnapshots()
{
    #create empty array
    SNAPSHOTS=()

    snapshot_list=$(aliyun ecs DescribeSnapshots --RegionId $(getInstanceRegion) --DiskId $1 --PageSize 100 | egrep -Eow 'SnapshotId":"([^"]*)"' | cut -d":" -f 2 | tr -d '"')

    while read line
    do
        # add snapshot to global array
        SNAPSHOTS+=(${line})

    done <<< "$(echo -e "$snapshot_list")"
}


#
# RETURNS SNAPSHOT CREATED DATE
#
# input: ${SNAPSHOT_ID}
#

getSnapshotCreatedDate()
{
    json_snapshot_id="[\"$1\"]"

    local snapshot_datetime=$(aliyun ecs DescribeSnapshots --RegionId $(getInstanceRegion) --SnapshotIds $json_snapshot_id | egrep -Eow 'CreationTime":"([^"]*)"' | cut -d':' -f2- | tr -d ',' | sed -e 's/"//g' -e 's;/dev/;;')

    # format date
    echo -e "$(date -d ${snapshot_datetime} +%s)"
}


#
# DELETES SNAPSHOT
#
# input ${SNAPSHOT_ID}
# 

deleteSnapshot()
{
    echo -e "$(aliyun ecs DeleteSnapshot --SnapshotId $1)"
}


logTime()
{
    local datetime="$(date +"%Y-%m-%d %T")"
    echo -e "$datetime: $1"
}


#######################
##                   ##
## WRAPPER FUNCTIONS ##
##                   ##
#######################


createSnapshotWrapper()
{
    # log time
    logTime "Start of createSnapshotWrapper"

    # get date time
    DATE_TIME="$(date "+%s")"

    # get the instance name
    INSTANCE_NAME=$(getInstanceName)

    # get the instance id
    INSTANCE_ID=$(getInstanceId)

    # get the instance zone
    #INSTANCE_ZONE=$(getInstanceRegion)

    # get a list of all the devices
    DEVICE_LIST=$(getDeviceList)

    # create the snapshots
    echo "${DEVICE_LIST}" | while read DEVICE_ID
    do
         if [[ -n "$OPT_FILTER" ]];then
              if ! [[ $(getDeviceName $DEVICE_ID) =~ $OPT_FILTER ]]; then
                   getSnapshots $DEVICE_ID 
                   if [ "${#SNAPSHOTS[@]}" -lt $SNAPSHOT_QUOTA ];then
                        # create snapshot name
                        SNAPSHOT_NAME=$(createSnapshotName $INSTANCE_NAME $(getDeviceType $DEVICE_ID) $(getDeviceFile $DEVICE_ID) $DATE_TIME)
                        # create the snapshot    
                        OUTPUT_SNAPSHOT_CREATION=$(createSnapshot ${DEVICE_ID} ${SNAPSHOT_NAME})
                   fi
              fi 
         else
              getSnapshots $DEVICE_ID
              if [ "${#SNAPSHOTS[@]}" -lt $SNAPSHOT_QUOTA ];then
                   # create snapshot name
                   SNAPSHOT_NAME=$(createSnapshotName $INSTANCE_NAME $(getDeviceType $DEVICE_ID) $(getDeviceFile $DEVICE_ID) $DATE_TIME)
                   # create the snapshot
                   OUTPUT_SNAPSHOT_CREATION=$(createSnapshot ${DEVICE_ID} ${SNAPSHOT_NAME})
              fi
         fi
    done
}


deleteSnapshotsWrapper()
{
    # log time
    logTime "Start of deleteSnapshotsWrapper"

    # get a list of all the devices
    DEVICE_LIST=$(getDeviceList)
    
    # delete the snapshots
    echo "${DEVICE_LIST}" | while read DEVICE_ID
    do
        # while > 64?
        ## get list of snapshots - saved in global array 
        getSnapshots $DEVICE_ID 
        if [ "${#SNAPSHOTS[@]}" -ge $SNAPSHOT_QUOTA ];then
             # we want to find the oldest snapshot
             SNAPSHOT_TO_DELETE=''
             REF_TIMESTAMP="$(date +%s)"
             for snapshot in "${SNAPSHOTS[@]}"
             do
                 # get created date for snapshot
                 CUR_TIMESTAMP=$(getSnapshotCreatedDate ${snapshot})
                 if [ "$CUR_TIMESTAMP" -lt "$REF_TIMESTAMP" ];then
                     REF_TIMESTAMP=$CUR_TIMESTAMP
                     SNAPSHOT_TO_DELETE=$snapshot
                 fi
             done
             if [[ -n $SNAPSHOT_TO_DELETE ]]; then
                 OUTPUT_SNAPSHOT_DELETION=$(deleteSnapshot $SNAPSHOT_TO_DELETE)
             fi
        fi
    done
}




##########################
##                      ##
## RUN SCRIPT FUNCTIONS ##
##                      ##
##########################

# log time
logTime "Start of Script"

# set options from script input / default value
setScriptOptions "$@"

# delete snapshots older than 'x' days
deleteSnapshotsWrapper

# create snapshot
createSnapshotWrapper

# log time
logTime "End of Script"
