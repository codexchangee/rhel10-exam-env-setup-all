#!/usr/bin/env bash

############################################################

# RHCSA RHEL10 EXAM CHECKER

# PART 1

# Workstation -> Node1 / Node2

############################################################

set -u
set -o pipefail
IFS=$'\n\t'

############################################################

# CONFIGURATION

############################################################

NODE1="primary.net1.example.com"
NODE2="secondary.net1.example.com"

ROOT_PASS="Ventyol"

TOTAL_MARKS=300
PASS_MARKS=210
SCORE=0

NODE1_SCORE=0
NODE2_SCORE=0

declare -a SUMMARY

############################################################

# COLORS

############################################################

green="\e[32m"
red="\e[31m"
yellow="\e[33m"
blue="\e[34m"
bold="\e[1m"
reset="\e[0m"

############################################################

# HELPERS

############################################################

need_root() {
[[ $EUID -eq 0 ]] || {
echo "Run as root"
exit 1
}
}

ensure_sshpass() {
if ! command -v sshpass >/dev/null 2>&1
then
dnf install -y sshpass >/dev/null 2>&1 
|| yum install -y sshpass >/dev/null 2>&1
fi
}

run_remote() {
local host="$1"
shift

```
sshpass -p "$ROOT_PASS" \
  ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  root@"$host" "$@"
```

}

award_marks() {
local marks="$1"
local node="$2"

```
SCORE=$(( SCORE + marks ))

if [[ "$node" == "node1" ]]
then
    NODE1_SCORE=$(( NODE1_SCORE + marks ))
else
    NODE2_SCORE=$(( NODE2_SCORE + marks ))
fi
```

}

pass_line() {
echo -e "${green}PASS${reset} $1"
}

fail_line() {
echo -e "${red}FAIL${reset} $1"
}

add_summary() {
SUMMARY+=("$1|$2|$3|$4")
}

############################################################

# PRECHECKS

############################################################

need_root
ensure_sshpass

echo
echo -e "${bold}${blue}========================================${reset}"
echo -e "${bold}${blue} RHCSA RHEL10 PAPER CHECKER${reset}"
echo -e "${bold}${blue}========================================${reset}"

############################################################

# NODE1 CONNECTIVITY

############################################################

echo
echo -e "${bold}${blue}Connecting Node1${reset}"

if run_remote "$NODE1" "hostname" >/dev/null 2>&1
then
pass_line "Node1 reachable"
else
echo "Unable to connect to Node1"
exit 1
fi

############################################################

# Q1 NETWORK CONFIGURATION (12)

############################################################

echo
echo "Q1 Network Configuration [12]"

qscore=0

HOSTNAME_CHECK=$(run_remote "$NODE1" "hostnamectl --static" 2>/dev/null)

if [[ "$HOSTNAME_CHECK" == "primary.net1.example.com" ]]
then
qscore=$((qscore+3))
pass_line "Hostname"
else
fail_line "Hostname"
fi

if run_remote "$NODE1" 
"ip -4 addr | grep -q '172.25.1.11/'"
then
qscore=$((qscore+3))
pass_line "IP Address"
else
fail_line "IP Address"
fi

if run_remote "$NODE1" 
"ip route | grep -q 'default via 172.25.1.254'"
then
qscore=$((qscore+3))
pass_line "Gateway"
else
fail_line "Gateway"
fi

if run_remote "$NODE1" 
"grep -q '172.25.254.254' /etc/resolv.conf"
then
qscore=$((qscore+3))
pass_line "DNS"
else
fail_line "DNS"
fi

award_marks "$qscore" node1
add_summary "Q1" "Network" "$qscore" "12"

############################################################

# Q2 REPOSITORY CONFIGURATION (8)

############################################################

echo
echo "Q2 Repository Configuration [8]"

qscore=0

if run_remote "$NODE1" 
"grep -R 'mirror.stream.centos.org/9-stream/AppStream' 
/etc/yum.repos.d/* >/dev/null 2>&1"
then
qscore=$((qscore+4))
pass_line "AppStream Repo"
else
fail_line "AppStream Repo"
fi

if run_remote "$NODE1" 
"grep -R 'mirror.stream.centos.org/9-stream/BaseOS' 
/etc/yum.repos.d/* >/dev/null 2>&1"
then
qscore=$((qscore+4))
pass_line "BaseOS Repo"
else
fail_line "BaseOS Repo"
fi

award_marks "$qscore" node1
add_summary "Q2" "Repository" "$qscore" "8"

############################################################

# Q3 HTTPD + SELINUX (18)

############################################################

echo
echo "Q3 HTTPD + SELinux [18]"

qscore=0

if run_remote "$NODE1" 
"systemctl is-active httpd >/dev/null"
then
qscore=$((qscore+4))
pass_line "HTTPD Active"
else
fail_line "HTTPD Active"
fi

if run_remote "$NODE1" 
"systemctl is-enabled httpd >/dev/null"
then
qscore=$((qscore+4))
pass_line "HTTPD Enabled"
else
fail_line "HTTPD Enabled"
fi

if run_remote "$NODE1" 
"ss -tln | grep -q ':82 '"
then
qscore=$((qscore+4))
pass_line "Port 82 Listening"
else
fail_line "Port 82 Listening"
fi

if run_remote "$NODE1" 
"semanage port -l 2>/dev/null | grep http_port_t | grep -q 82"
then
qscore=$((qscore+3))
pass_line "SELinux Port"
else
fail_line "SELinux Port"
fi

if run_remote "$NODE1" 
"curl -s http://localhost:82 | grep -qi 'Ex200'"
then
qscore=$((qscore+3))
pass_line "Content Accessible"
else
fail_line "Content Accessible"
fi

award_marks "$qscore" node1
add_summary "Q3" "HTTPD" "$qscore" "18"

############################################################

# Q4 USERS & GROUPS (12)

############################################################

echo
echo "Q4 Users and Groups [12]"

qscore=0

if run_remote "$NODE1" 
"getent group sysadmin >/dev/null"
then
qscore=$((qscore+3))
pass_line "Group sysadmin"
else
fail_line "Group sysadmin"
fi

if run_remote "$NODE1" 
"id natasha | grep -q sysadmin"
then
qscore=$((qscore+3))
pass_line "Natasha"
else
fail_line "Natasha"
fi

if run_remote "$NODE1" 
"id harry | grep -q sysadmin"
then
qscore=$((qscore+3))
pass_line "Harry"
else
fail_line "Harry"
fi

if run_remote "$NODE1" 
"getent passwd sarah | grep -Eq '(nologin|false)$'"
then
qscore=$((qscore+3))
pass_line "Sarah Shell"
else
fail_line "Sarah Shell"
fi

award_marks "$qscore" node1
add_summary "Q4" "Users" "$qscore" "12"

############################################################

# Q5 CRON (8)

############################################################

echo
echo "Q5 Cron [8]"

qscore=0

if run_remote "$NODE1" 
"crontab -u natasha -l 2>/dev/null | grep -q '23 14'"
then
qscore=8
pass_line "Cron Exists"
else
fail_line "Cron Missing"
fi

award_marks "$qscore" node1
add_summary "Q5" "Cron" "$qscore" "8"

############################################################

# Q6 COLLABORATIVE DIRECTORY (8)

############################################################

echo
echo "Q6 Collaborative Directory [8]"

qscore=0

if run_remote "$NODE1" 
"stat -c %G /common/admin 2>/dev/null | grep -qx sysadmin"
then
qscore=$((qscore+4))
pass_line "Group Ownership"
else
fail_line "Group Ownership"
fi

if run_remote "$NODE1" 
"stat -c %a /common/admin 2>/dev/null | grep -qx 2770"
then
qscore=$((qscore+4))
pass_line "Permissions"
else
fail_line "Permissions"
fi

award_marks "$qscore" node1
add_summary "Q6" "Directory" "$qscore" "8"

############################################################

# Q7 NTP (8)

############################################################

echo
echo "Q7 NTP [8]"

qscore=0

if run_remote "$NODE1" 
"grep -q '3.in.pool.ntp.org' /etc/chrony.conf"
then
qscore=$((qscore+4))
pass_line "Chrony Config"
else
fail_line "Chrony Config"
fi

if run_remote "$NODE1" 
"systemctl is-active chronyd >/dev/null"
then
qscore=$((qscore+4))
pass_line "Chronyd Active"
else
fail_line "Chronyd Active"
fi

award_marks "$qscore" node1
add_summary "Q7" "NTP" "$qscore" "8"

############################################################

# Q8 SIMONE FILES (8)

############################################################

echo
echo "Q8 Simone Files [8]"

qscore=0

if run_remote "$NODE1" 
"test -d /root/found"
then
qscore=$((qscore+4))
pass_line "Directory Exists"
else
fail_line "Directory Exists"
fi

if run_remote "$NODE1" 
"find /root/found -type f | grep -q ."
then
qscore=$((qscore+4))
pass_line "Files Copied"
else
fail_line "Files Copied"
fi

award_marks "$qscore" node1
add_summary "Q8" "Simone Files" "$qscore" "8"

############################################################

# END PART 1

############################################################

echo
echo "PART 1 COMPLETE"
echo "Node1 Score So Far : $NODE1_SCORE"
echo "Overall Score      : $SCORE"

# Continue with PART 2

############################################################

# PART 2

# NODE1 Q9 - Q16

############################################################

############################################################

# Q9 SEARCH STRING (4)

############################################################

echo
echo "Q9 Search String [4]"

qscore=0

if run_remote "$NODE1" 
"grep -qi strato /searchfile 2>/dev/null"
then
qscore=4
pass_line "Search Output Correct"
else
fail_line "Search Output Missing"
fi

award_marks "$qscore" node1
add_summary "Q9" "Search String" "$qscore" "4"

############################################################

# Q10 AUTOFS (35)

############################################################

echo
echo "Q10 Autofs [35]"

qscore=0

if run_remote "$NODE1" 
"systemctl is-enabled autofs >/dev/null 2>&1"
then
qscore=$((qscore+5))
pass_line "Autofs Enabled"
else
fail_line "Autofs Enabled"
fi

if run_remote "$NODE1" 
"systemctl is-active autofs >/dev/null 2>&1"
then
qscore=$((qscore+5))
pass_line "Autofs Active"
else
fail_line "Autofs Active"
fi

if run_remote "$NODE1" 
"grep -q '/rhome' /etc/auto.master"
then
qscore=$((qscore+10))
pass_line "auto.master Configured"
else
fail_line "auto.master Configured"
fi

if run_remote "$NODE1" 
"grep -qi remoteuser2 /etc/auto.misc"
then
qscore=$((qscore+10))
pass_line "auto.misc Configured"
else
fail_line "auto.misc Configured"
fi

if run_remote "$NODE1" 
"ls /rhome/remoteuser2 >/dev/null 2>&1"
then
qscore=$((qscore+5))
pass_line "Mount Working"
else
fail_line "Mount Working"
fi

award_marks "$qscore" node1
add_summary "Q10" "Autofs" "$qscore" "35"

############################################################

# Q11 NEWSEARCH SCRIPT (18)

############################################################

echo
echo "Q11 newsearch Script [18]"

qscore=0

if run_remote "$NODE1" 
"test -f /usr/local/bin/newsearch"
then
qscore=$((qscore+4))
pass_line "Script Exists"
else
fail_line "Script Exists"
fi

if run_remote "$NODE1" 
"test -x /usr/local/bin/newsearch"
then
qscore=$((qscore+4))
pass_line "Executable"
else
fail_line "Executable"
fi

if run_remote "$NODE1" 
"grep -q 'find /usr' /usr/local/bin/newsearch"
then
qscore=$((qscore+5))
pass_line "Find Logic Present"
else
fail_line "Find Logic Present"
fi

if run_remote "$NODE1" 
"test -f /root/myoutput"
then
qscore=$((qscore+5))
pass_line "Output File Generated"
else
fail_line "Output File Generated"
fi

award_marks "$qscore" node1
add_summary "Q11" "newsearch" "$qscore" "18"

############################################################

# Q12 BARRY USER (4)

############################################################

echo
echo "Q12 Barry User [4]"

qscore=0

if run_remote "$NODE1" 
"id -u barry 2>/dev/null | grep -qx 2112"
then
qscore=4
pass_line "Barry UID Correct"
else
fail_line "Barry UID Incorrect"
fi

award_marks "$qscore" node1
add_summary "Q12" "Barry User" "$qscore" "4"

############################################################

# Q13 UMASK + SUDO + PASS_MAX_DAYS + EX200 (20)

############################################################

echo
echo "Q13 Composite Question [20]"

qscore=0

# UMASK

if run_remote "$NODE1" 
"su - alex -c 'umask' 2>/dev/null | grep -q 0222"
then
qscore=$((qscore+5))
pass_line "UMASK"
else
fail_line "UMASK"
fi

# SUDO

if run_remote "$NODE1" 
"grep -R '%elite.*NOPASSWD' /etc/sudoers /etc/sudoers.d/* \

> /dev/null 2>&1"
> then
> qscore=$((qscore+5))
> pass_line "Elite Sudo"
> else
> fail_line "Elite Sudo"
> fi

# PASSWORD POLICY

if run_remote "$NODE1" 
"grep -E '^PASS_MAX_DAYS[[:space:]]+20' 
/etc/login.defs >/dev/null"
then
qscore=$((qscore+5))
pass_line "PASS_MAX_DAYS"
else
fail_line "PASS_MAX_DAYS"
fi

# EX200 SCRIPT

if run_remote "$NODE1" 
"su - harry -c './ex200' 2>/dev/null | 
grep -qi 'Ex200 Pass Progress Results'"
then
qscore=$((qscore+5))
pass_line "Application"
else
fail_line "Application"
fi

award_marks "$qscore" node1
add_summary "Q13" "Composite" "$qscore" "20"

############################################################

# Q14 BACKUP (5)

############################################################

echo
echo "Q14 Backup [5]"

qscore=0

if run_remote "$NODE1" 
"file /home/backup.tar.bz2 2>/dev/null | 
grep -qi bzip2"
then
qscore=$((qscore+3))
pass_line "Archive Exists"
else
fail_line "Archive Exists"
fi

if run_remote "$NODE1" 
"tar -tjf /home/backup.tar.bz2 2>/dev/null | 
grep -q '^etc/'"
then
qscore=$((qscore+2))
pass_line "Contains /etc"
else
fail_line "Contains /etc"
fi

award_marks "$qscore" node1
add_summary "Q14" "Backup" "$qscore" "5"

############################################################

# Q15 LOGGER + TIMER (25)

############################################################

echo
echo "Q15 Logger Timer [25]"

qscore=0

if run_remote "$NODE1" 
"rpm -q logger >/dev/null 2>&1"
then
qscore=$((qscore+3))
pass_line "Package Installed"
else
fail_line "Package Installed"
fi

if run_remote "$NODE1" 
"test -x /usr/local/bin/logger"
then
qscore=$((qscore+5))
pass_line "Logger Script"
else
fail_line "Logger Script"
fi

if run_remote "$NODE1" 
"systemctl list-unit-files | grep -q '^logger.service'"
then
qscore=$((qscore+5))
pass_line "Service Exists"
else
fail_line "Service Exists"
fi

if run_remote "$NODE1" 
"systemctl list-unit-files | grep -q '^logger.timer'"
then
qscore=$((qscore+5))
pass_line "Timer Exists"
else
fail_line "Timer Exists"
fi

if run_remote "$NODE1" 
"test -f /root/lookup_directory/ex200"
then
qscore=$((qscore+7))
pass_line "Output Generated"
else
fail_line "Output Generated"
fi

award_marks "$qscore" node1
add_summary "Q15" "Logger Timer" "$qscore" "25"

############################################################

# Q16 ACL (12)

############################################################

echo
echo "Q16 ACL [12]"

qscore=0

if run_remote "$NODE1" 
"test -f /var/tmp/fstab"
then
qscore=$((qscore+2))
pass_line "File Exists"
else
fail_line "File Exists"
fi

if run_remote "$NODE1" 
"getfacl /var/tmp/fstab | grep -q 'user:natasha:rw-'"
then
qscore=$((qscore+4))
pass_line "Natasha ACL"
else
fail_line "Natasha ACL"
fi

if run_remote "$NODE1" 
"getfacl /var/tmp/fstab | grep -q 'user:harry:---'"
then
qscore=$((qscore+3))
pass_line "Harry ACL"
else
fail_line "Harry ACL"
fi

if run_remote "$NODE1" 
"getfacl /var/tmp/fstab | grep -q 'other::r--'"
then
qscore=$((qscore+3))
pass_line "Others Read"
else
fail_line "Others Read"
fi

award_marks "$qscore" node1
add_summary "Q16" "ACL" "$qscore" "12"

############################################################

# NODE1 COMPLETE

############################################################

echo
echo "======================================="
echo "NODE1 COMPLETE"
echo "NODE1 SCORE : $NODE1_SCORE"
echo "OVERALL SCORE : $SCORE"
echo "======================================="

# Continue with PART 3

############################################################

# PART 3

# NODE2 Q17 - Q21

############################################################

echo
echo -e "${bold}${blue}Connecting Node2${reset}"

if run_remote "$NODE2" "hostname" >/dev/null 2>&1
then
pass_line "Node2 reachable"
else
echo "Unable to connect to Node2"
exit 1
fi

############################################################

# Q17 TUNED PROFILE (8)

############################################################

echo
echo "Q17 Tuned Profile [8]"

qscore=0

if run_remote "$NODE2" 
"systemctl is-enabled tuned >/dev/null 2>&1"
then
qscore=$((qscore+3))
pass_line "Tuned Enabled"
else
fail_line "Tuned Enabled"
fi

if run_remote "$NODE2" 
"systemctl is-active tuned >/dev/null 2>&1"
then
qscore=$((qscore+3))
pass_line "Tuned Active"
else
fail_line "Tuned Active"
fi

if run_remote "$NODE2" 
"tuned-adm active | grep -q ':'"
then
qscore=$((qscore+2))
pass_line "Profile Applied"
else
fail_line "Profile Applied"
fi

award_marks "$qscore" node2
add_summary "Q17" "Tuned" "$qscore" "8"

############################################################

# Q18 FLATPAK (18)

############################################################

echo
echo "Q18 Flatpak [18]"

qscore=0

if run_remote "$NODE2" 
"su - bammbamm -c 'flatpak remotes --user' 
2>/dev/null | grep -qx extra"
then
qscore=$((qscore+6))
pass_line "Remote extra"
else
fail_line "Remote extra"
fi

if run_remote "$NODE2" 
"su - bammbamm -c 'flatpak list --user' 
2>/dev/null | grep -qi codium"
then
qscore=$((qscore+6))
pass_line "Codium Installed"
else
fail_line "Codium Installed"
fi

if run_remote "$NODE2" 
"! flatpak remotes --system 2>/dev/null | grep -q extra"
then
qscore=$((qscore+6))
pass_line "User Only Repository"
else
fail_line "User Only Repository"
fi

award_marks "$qscore" node2
add_summary "Q18" "Flatpak" "$qscore" "18"

############################################################

# Q19 SWAP (20)

############################################################

echo
echo "Q19 Swap [20]"

qscore=0

if run_remote "$NODE2" 
"swapon --show | grep -q '/dev/'"
then
qscore=$((qscore+5))
pass_line "Swap Active"
else
fail_line "Swap Active"
fi

if run_remote "$NODE2" 
"swapon --show=SIZE --bytes | 
awk 'NR>1 {if($1>=250000000) exit 0; else exit 1}'"
then
qscore=$((qscore+5))
pass_line "Size >= 250MB"
else
fail_line "Size >= 250MB"
fi

if run_remote "$NODE2" 
"grep -q 'swap' /etc/fstab"
then
qscore=$((qscore+5))
pass_line "Persistent"
else
fail_line "Persistent"
fi

if run_remote "$NODE2" 
"cat /proc/swaps | grep -q '/dev/'"
then
qscore=$((qscore+5))
pass_line "In Use"
else
fail_line "In Use"
fi

award_marks "$qscore" node2
add_summary "Q19" "Swap" "$qscore" "20"

############################################################

# Q20 LVM CREATION (30)

############################################################

echo
echo "Q20 LVM Creation [30]"

qscore=0

if run_remote "$NODE2" 
"pvs 2>/dev/null | grep -q '/dev/vdb'"
then
qscore=$((qscore+5))
pass_line "PV Created"
else
fail_line "PV Created"
fi

if run_remote "$NODE2" 
"vgs myvol >/dev/null 2>&1"
then
qscore=$((qscore+5))
pass_line "VG myvol"
else
fail_line "VG myvol"
fi

if run_remote "$NODE2" 
"vgs myvol --units m --noheadings -o vg_extent_size 
2>/dev/null | grep -q '8.00m'"
then
qscore=$((qscore+5))
pass_line "PE Size 8M"
else
fail_line "PE Size 8M"
fi

if run_remote "$NODE2" 
"lvs myvol/mydatabase >/dev/null 2>&1"
then
qscore=$((qscore+5))
pass_line "LV mydatabase"
else
fail_line "LV mydatabase"
fi

if run_remote "$NODE2" 
"blkid /dev/myvol/mydatabase | grep -qi ext3"
then
qscore=$((qscore+5))
pass_line "Filesystem ext3"
else
fail_line "Filesystem ext3"
fi

if run_remote "$NODE2" 
"findmnt /mnt/database >/dev/null 2>&1"
then
qscore=$((qscore+5))
pass_line "Mounted"
else
fail_line "Mounted"
fi

award_marks "$qscore" node2
add_summary "Q20" "LVM Creation" "$qscore" "30"

############################################################

# Q21 LVM RESIZE (15)

############################################################

echo
echo "Q21 LVM Resize [15]"

qscore=0

if run_remote "$NODE2" 
"lvs --units m --noheadings -o lv_size 2>/dev/null | 
grep -E '350.00m|349.|351.'"
then
qscore=$((qscore+10))
pass_line "Home LV Resized"
else
fail_line "Home LV Resized"
fi

if run_remote "$NODE2" 
"findmnt /home >/dev/null 2>&1"
then
qscore=$((qscore+5))
pass_line "Filesystem Mounted"
else
fail_line "Filesystem Mounted"
fi

award_marks "$qscore" node2
add_summary "Q21" "LVM Resize" "$qscore" "15"

############################################################

# NODE2 COMPLETE

############################################################

echo
echo "======================================="
echo "NODE2 COMPLETE"
echo "NODE2 SCORE : $NODE2_SCORE"
echo "OVERALL SCORE : $SCORE"
echo "======================================="

# Continue with PART 4
############################################################

# PART 4

# FINAL REPORTING

############################################################

echo
echo
echo -e "${bold}${blue}=========================================${reset}"
echo -e "${bold}${blue}          RHCSA RHEL10 REPORT            ${reset}"
echo -e "${bold}${blue}=========================================${reset}"

printf "\n"

printf "%-6s %-30s %-10s\n" "QNO" "TASK" "SCORE"
printf "%-6s %-30s %-10s\n" "----" "------------------------------" "----------"

for row in "${SUMMARY[@]}"
do
IFS='|' read -r q task score total <<< "$row"

```
if [[ "$score" == "$total" ]]
then
    printf "${green}%-6s %-30s %-10s${reset}\n" \
        "$q" "$task" "$score/$total"
elif [[ "$score" -eq 0 ]]
then
    printf "${red}%-6s %-30s %-10s${reset}\n" \
        "$q" "$task" "$score/$total"
else
    printf "${yellow}%-6s %-30s %-10s${reset}\n" \
        "$q" "$task" "$score/$total"
fi
```

done

echo
echo "================================================="
echo "NODE1 SCORE : $NODE1_SCORE"
echo "NODE2 SCORE : $NODE2_SCORE"
echo "================================================="

PERCENTAGE=$(( SCORE * 100 / TOTAL_MARKS ))

echo
echo "================================================="
echo "TOTAL MARKS : $TOTAL_MARKS"
echo "PASS MARKS  : $PASS_MARKS"
echo "OBTAINED    : $SCORE"
echo "PERCENTAGE  : ${PERCENTAGE}%"
echo "================================================="

############################################################

# GRADE

############################################################

if (( SCORE >= PASS_MARKS ))
then
RESULT="PASS"
RESULT_COLOR="$green"
else
RESULT="FAIL"
RESULT_COLOR="$red"
fi

echo
echo -e "${bold}${RESULT_COLOR}=========================================${reset}"
echo -e "${bold}${RESULT_COLOR} RESULT : $RESULT${reset}"
echo -e "${bold}${RESULT_COLOR}=========================================${reset}"

############################################################

# PERFORMANCE ANALYSIS

############################################################

echo
echo "Performance Analysis"
echo "--------------------"

if (( PERCENTAGE >= 90 ))
then
echo "Excellent Performance"
elif (( PERCENTAGE >= 80 ))
then
echo "Very Good Performance"
elif (( PERCENTAGE >= 70 ))
then
echo "Good Performance"
elif (( PERCENTAGE >= 60 ))
then
echo "Needs Improvement"
else
echo "Requires Significant Improvement"
fi

############################################################

# FAILED QUESTIONS

############################################################

echo
echo "Failed / Partial Questions"
echo "--------------------------"

FOUND=0

for row in "${SUMMARY[@]}"
do
IFS='|' read -r q task score total <<< "$row"

```
if (( score < total ))
then
    FOUND=1
    echo "$q  $task  ($score/$total)"
fi
```

done

if (( FOUND == 0 ))
then
echo "None"
fi

############################################################

# TOP SCORING SECTIONS

############################################################

echo
echo "Major Weighted Questions"
echo "------------------------"

for row in "${SUMMARY[@]}"
do
IFS='|' read -r q task score total <<< "$row"

```
if (( total >= 20 ))
then
    echo "$q  $task  ($score/$total)"
fi
```

done

############################################################

# LOG FILE

############################################################

REPORT_FILE="/root/rhel10_exam_report.txt"

{
echo "RHCSA RHEL10 REPORT"
echo "Generated : $(date)"
echo

for row in "${SUMMARY[@]}"
do
IFS='|' read -r q task score total <<< "$row"
echo "$q | $task | $score/$total"
done

echo
echo "NODE1 SCORE : $NODE1_SCORE"
echo "NODE2 SCORE : $NODE2_SCORE"
echo "TOTAL SCORE : $SCORE/$TOTAL_MARKS"
echo "PERCENTAGE  : $PERCENTAGE%"
echo "RESULT      : $RESULT"

} > "$REPORT_FILE"

echo
echo "Report saved to:"
echo "$REPORT_FILE"

############################################################

# FINAL OUTPUT

############################################################

echo
echo -e "${bold}${blue}=========================================${reset}"
echo -e "${bold}${blue} Checker Completed Successfully${reset}"
echo -e "${bold}${blue}=========================================${reset}"

exit 0

############################################################

# END OF SCRIPT

############################################################

