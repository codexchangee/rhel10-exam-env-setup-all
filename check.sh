#!/usr/bin/env bash
# RHEL 10 RHCSA exam checker for the supplied question2-question21 HTML files.
# Read-only checker: it does not modify or clean either exam machine.
set -uo pipefail
IFS=$'\n\t'

NODE1="${NODE1:-172.25.250.10}"
NODE2="${NODE2:-172.25.250.11}"
NODE1_ROOT_PASS="${NODE1_ROOT_PASS:-radiowits}"
NODE2_ROOT_PASS="${NODE2_ROOT_PASS:-atenorth}"
SSH_USER="${SSH_USER:-root}"
PASS_MARKS="${PASS_MARKS:-210}"
TOTAL_MARKS=300

GREEN=$'\033[32m'; RED=$'\033[31m'; YELLOW=$'\033[33m'; BLUE=$'\033[34m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
TOTAL_EARNED=0
SUMMARY=()

need_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    echo "ERROR: Run with sudo/root. Example: sudo paper-check"
    exit 1
  fi
}

ensure_sshpass() {
  if ! command -v sshpass >/dev/null 2>&1; then
    echo "sshpass is required for the existing password-based SSH workflow. Installing..."
    if command -v dnf >/dev/null 2>&1; then
      dnf install -y sshpass || { echo "ERROR: Could not install sshpass. Install it and rerun."; exit 1; }
    elif command -v yum >/dev/null 2>&1; then
      yum install -y sshpass || { echo "ERROR: Could not install sshpass. Install it and rerun."; exit 1; }
    else
      echo "ERROR: dnf/yum not found; install sshpass manually."; exit 1
    fi
  fi
}

# Each check feeds a read-only shell snippet to the remote host. It is isolated,
# so one failed question does not stop later questions.
run_remote_check() {
  local q="$1" weight="$2" description="$3" host="$4" password="$5" snippet="$6"
  local output rc=0
  output=$(printf '%s\n' "$snippet" | SSHPASS="$password" sshpass -e ssh \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=6 \
    -o ServerAliveInterval=5 \
    -o ServerAliveCountMax=1 \
    "${SSH_USER}@${host}" 'bash -s' 2>&1) || rc=$?

  if (( rc == 0 )); then
    printf '  %sPASS%s %-4s %2d marks - %s\n' "$GREEN" "$RESET" "$q" "$weight" "$description"
    TOTAL_EARNED=$((TOTAL_EARNED + weight))
    SUMMARY+=("$q|$description|PASS|$weight")
  else
    printf '  %sFAIL%s %-4s %2d marks - %s\n' "$RED" "$RESET" "$q" "$weight" "$description"
    if [[ -n "$output" ]]; then
      # Keep the report concise; useful remote diagnostics are shown on failure.
      printf '       %s\n' "$(printf '%s\n' "$output" | tail -n 2 | tr '\n' ' ')"
    fi
    SUMMARY+=("$q|$description|FAIL|$weight")
  fi
}

need_root
ensure_sshpass

printf '%s%sRHEL 10 RHCSA CHECKER%s\n' "$BLUE" "$BOLD" "$RESET"
printf 'Node1: %s (Q02-Q14; Q15 is not present in the supplied HTML set)\n' "$NODE1"
printf 'Node2: %s (Q16-Q22)\n' "$NODE2"
printf 'Scoring: %s total marks; pass at %s marks\n\n' "$TOTAL_MARKS" "$PASS_MARKS"

# The supplied HTML files contain 20 tasks. Their visible task labels skip Task 15
# and contain stale labels for Flatpak/swap/LVM. IDs below follow the intended task
# sequence from the file contents: root password is Q16, resize is Q22.

printf '%s%sChecking node1 tasks%s\n' "$BLUE" "$BOLD" "$RESET"

run_remote_check Q02 13 'Network hostname/IP/gateway/DNS' "$NODE1" "$NODE1_ROOT_PASS" '
set -u
hostnamectl --static | grep -qx "primary.net1.example.com" || exit 1
ip -o -4 addr show | grep -Eq "inet 172\.25\.250\.11/24([[:space:]]|$)" || exit 1
ip -4 route show default | grep -q "via 172.25.250.254" || exit 1
nmcli -t -f IP4.DNS device show 2>/dev/null | grep -q "172.25.250.220" || grep -Rqs "172.25.250.220" /etc/NetworkManager/system-connections
'

run_remote_check Q03 13 'BaseOS and AppStream default repositories' "$NODE1" "$NODE1_ROOT_PASS" '
set -u
r=/etc/yum.repos.d
 grep -Rqs "content.example.com/rhel10.0/x86_64/dvd/BaseOS" "$r" || exit 1
 grep -Rqs "content.example.com/rhel10.0/x86_64/dvd/AppStream" "$r" || exit 1
'

run_remote_check Q04 13 'httpd on port 82, SELinux, boot enablement and local page' "$NODE1" "$NODE1_ROOT_PASS" '
set -u
systemctl is-active --quiet httpd || exit 1
systemctl is-enabled --quiet httpd || exit 1
ss -ltn | awk "NR>1 {print \$4}" | grep -Eq "(^|:)82$" || exit 1
curl --max-time 5 -fsS http://localhost:82/file1 >/dev/null || exit 1
if command -v getenforce >/dev/null 2>&1 && [[ $(getenforce) == Enforcing ]]; then
  command -v semanage >/dev/null 2>&1 || exit 1
  semanage port -l | awk "\$1 == \"http_port_t\" {for (i=2;i<=NF;i++) if (\$i == 82 || \$i ~ /,82,/) found=1} END {exit !found}"
fi
'

run_remote_check Q05 13 'sysadmin group and natasha/harry/sarah account requirements' "$NODE1" "$NODE1_ROOT_PASS" '
set -u
getent group sysadmin >/dev/null || exit 1
id natasha >/dev/null 2>&1 && id harry >/dev/null 2>&1 && id sarah >/dev/null 2>&1 || exit 1
id -nG natasha | tr " " "\n" | grep -qx sysadmin || exit 1
id -nG harry | tr " " "\n" | grep -qx sysadmin || exit 1
! id -nG sarah | tr " " "\n" | grep -qx sysadmin || exit 1
shell=$(getent passwd sarah | cut -d: -f7)
case "$shell" in */nologin|*/false) ;; *) exit 1 ;; esac
# Password values cannot be safely inferred from /etc/shadow; account structure is checked here.
'

run_remote_check Q06 13 'Natasha daily 14:23 cron and Harry every-3-minute logger cron' "$NODE1" "$NODE1_ROOT_PASS" '
set -u
n=$(crontab -u natasha -l 2>/dev/null || true)
h=$(crontab -u harry -l 2>/dev/null || true)
printf "%s\n" "$n" | grep -Eq "^[[:space:]]*23[[:space:]]+14[[:space:]]+\*[[:space:]]+\*[[:space:]]+\*[[:space:]].*/bin/echo[[:space:]]+hello([[:space:]]|$)" || exit 1
printf "%s\n" "$h" | grep -Eq "^[[:space:]]*\*/3[[:space:]]+\*[[:space:]]+\*[[:space:]]+\*[[:space:]]+\*[[:space:]].*/usr/bin/logger([[:space:]]|.*)EX200 in progress" || exit 1
'

run_remote_check Q07 13 'Compressed /etc backup at /home/backup.tar.bz2' "$NODE1" "$NODE1_ROOT_PASS" '
set -u
f=/home/backup.tar.bz2
[[ -s "$f" ]] || exit 1
tar -tjf "$f" 2>/dev/null | grep -Eq "(^|/)etc(/|$)" || exit 1
'

run_remote_check Q08 12 'chrony NTP client configured for classroom.example.com' "$NODE1" "$NODE1_ROOT_PASS" '
set -u
systemctl is-enabled --quiet chronyd || exit 1
systemctl is-active --quiet chronyd || exit 1
grep -RqsE "^[[:space:]]*(server|pool)[[:space:]]+classroom\.example\.com([[:space:]]|$)" /etc/chrony.conf /etc/chrony.d 2>/dev/null || exit 1
'

run_remote_check Q09 12 'Files owned by Simone copied into /root/found' "$NODE1" "$NODE1_ROOT_PASS" '
set -u
getent passwd Simone >/dev/null || getent passwd simone >/dev/null || exit 1
[[ -d /root/found ]] || exit 1
u=Simone; getent passwd "$u" >/dev/null || u=simone
src=$(find / -xdev -type f -user "$u" -not -path "/root/found/*" -not -path "/proc/*" -not -path "/sys/*" -not -path "/run/*" 2>/dev/null | wc -l)
dst=$(find /root/found -type f 2>/dev/null | wc -l)
(( src == 0 || dst >= src )) || exit 1
'

run_remote_check Q10 12 'grep strato result saved to /searchfile' "$NODE1" "$NODE1_ROOT_PASS" '
set -u
[[ -s /searchfile ]] || exit 1
grep -q "strato" /searchfile || exit 1
if [[ -r /usr/share/dict/words ]]; then grep -Fxf /searchfile /usr/share/dict/words >/dev/null 2>&1 || grep -Fq "strato" /searchfile || exit 1; fi
'

run_remote_check Q11 40 'Autofs writable NFS home for remoteuser2' "$NODE1" "$NODE1_ROOT_PASS" '
set -u
systemctl is-enabled --quiet autofs || exit 1
systemctl is-active --quiet autofs || exit 1
getent passwd remoteuser2 >/dev/null || exit 1
# Trigger the automount, then verify the mounted NFS source and export path.
timeout 10 ls -la /home/remoteuser2 >/dev/null 2>&1 || exit 1
src=$(findmnt -n -T /home/remoteuser2 -o SOURCE 2>/dev/null || true)
type=$(findmnt -n -T /home/remoteuser2 -o FSTYPE 2>/dev/null || true)
[[ "$type" == nfs || "$type" == nfs4 ]] || exit 1
[[ "$src" == *workstation.lab.example.com* || "$src" == *172.25.250.9* ]] || exit 1
[[ "$src" == */ourhome/remoteuser2* ]] || exit 1
runuser -u remoteuser2 -- test -w /home/remoteuser2 || exit 1
'

run_remote_check Q12 12 'barry user created with UID 2112' "$NODE1" "$NODE1_ROOT_PASS" '
set -u
[[ $(id -u barry 2>/dev/null) == 2112 ]] || exit 1
'

run_remote_check Q13 12 'newsearch, alex default permissions, elite sudo, password policy, ex200' "$NODE1" "$NODE1_ROOT_PASS" '
set -u
# newsearch must be executable, target /usr, filter the requested size range and SUID, and write output.
[[ -x /usr/local/bin/newsearch ]] || exit 1
grep -qE "(/usr|find)" /usr/local/bin/newsearch || exit 1
grep -qE -- "-perm[[:space:]]+(/4000|-4000)" /usr/local/bin/newsearch || exit 1
grep -qE "30k|30720" /usr/local/bin/newsearch || exit 1
grep -qE "50k|51200" /usr/local/bin/newsearch || exit 1
[[ -f /root/myoutput ]] || exit 1
# alex profile should set umask 0222 (files 444, directories 555).
getent passwd alex >/dev/null || exit 1
home=$(getent passwd alex | cut -d: -f6)
grep -RqsE "umask[[:space:]]+0?222" "$home/.bash_profile" "$home/.bashrc" /etc/profile.d 2>/dev/null || exit 1
getent group elite >/dev/null || exit 1
grep -RqsE "^[[:space:]]*%?elite[[:space:]]+.*NOPASSWD:[[:space:]]*ALL" /etc/sudoers /etc/sudoers.d 2>/dev/null || exit 1
grep -Eq "^[[:space:]]*PASS_MAX_DAYS[[:space:]]+20([[:space:]]|$)" /etc/login.defs || exit 1
command -v ex200 >/dev/null 2>&1 || exit 1
runuser -u aslan -- ex200 >/dev/null 2>&1 || exit 1
'

run_remote_check Q14 12 'logger systemd timer and /var/tmp/fstab ACL requirements' "$NODE1" "$NODE1_ROOT_PASS" '
set -u
rpm -q logger >/dev/null 2>&1 || exit 1
[[ -x /usr/local/bin/logger ]] || exit 1
[[ -e /root/lookup_directory/ex200 ]] || exit 1
svc=$(grep -RlE "ExecStart=.*(/usr/local/bin/logger|logger)" /etc/systemd/system /usr/lib/systemd/system 2>/dev/null | head -n1)
[[ -n "$svc" ]] || exit 1
timer=$(find /etc/systemd/system /usr/lib/systemd/system -maxdepth 2 -type f -name "*.timer" -print0 2>/dev/null | xargs -0 grep -lE "OnCalendar=.*\*:\*:00|OnUnitActiveSec=60|OnCalendar=.*minutely" 2>/dev/null | head -n1)
[[ -n "$timer" ]] || exit 1
systemctl is-active --quiet "$(basename "$timer")" || exit 1
systemctl is-enabled --quiet "$(basename "$timer")" || exit 1
[[ -f /var/tmp/fstab ]] || exit 1
[[ $(stat -c %U:%G /var/tmp/fstab) == root:root ]] || exit 1
mode=$(stat -c %a /var/tmp/fstab); (( (8#$mode & 0111) == 0 )) || exit 1
command -v getfacl >/dev/null 2>&1 || exit 1
acl=$(getfacl -cp /var/tmp/fstab 2>/dev/null) || exit 1
printf "%s\n" "$acl" | grep -Eq "^user:natasha:rw-?$" || exit 1
printf "%s\n" "$acl" | grep -Eq "^user:harry:---$" || exit 1
printf "%s\n" "$acl" | grep -Eq "^other::r--$" || exit 1
'

printf '\n%s%sChecking node2 tasks%s\n' "$BLUE" "$BOLD" "$RESET"

run_remote_check Q16 12 'Root password is atenorth (successful root SSH authentication)' "$NODE2" "$NODE2_ROOT_PASS" '
set -u
[[ $(id -u) == 0 ]]
'

run_remote_check Q17 12 'BaseOS and AppStream default repositories' "$NODE2" "$NODE2_ROOT_PASS" '
set -u
r=/etc/yum.repos.d
grep -Rqs "content.example.com/rhel10.0/x86_64/dvd/BaseOS" "$r" || exit 1
grep -Rqs "content.example.com/rhel10.0/x86_64/dvd/AppStream" "$r" || exit 1
'

run_remote_check Q18 12 'Recommended tuned profile active' "$NODE2" "$NODE2_ROOT_PASS" '
set -u
command -v tuned-adm >/dev/null 2>&1 || exit 1
recommended=$(tuned-adm recommend 2>/dev/null) || exit 1
active=$(tuned-adm active 2>/dev/null | sed -n "s/^Current active profile: //p")
[[ -n "$active" && "$active" == "$recommended" ]]
'

run_remote_check Q19 12 'Flatpak extra remote and codium installed for bammbamm only' "$NODE2" "$NODE2_ROOT_PASS" '
set -u
getent passwd bammbamm >/dev/null || exit 1
home=$(getent passwd bammbamm | cut -d: -f6)
[[ -d "$home" ]] || exit 1
# --user remotes and installations must be visible as bammbamm, not root.
runuser -u bammbamm -- env HOME="$home" XDG_DATA_HOME="$home/.local/share" flatpak remotes --user --columns=name 2>/dev/null | grep -qx extra || exit 1
runuser -u bammbamm -- env HOME="$home" XDG_DATA_HOME="$home/.local/share" flatpak list --user --app --columns=application 2>/dev/null | grep -Eqi "(^|\.)codium$|codium" || exit 1
if flatpak remotes --system --columns=name 2>/dev/null | grep -qx extra; then exit 1; fi
if flatpak list --system --app --columns=application 2>/dev/null | grep -Eqi "(^|\.)codium$|codium"; then exit 1; fi
'

run_remote_check Q20 20 '250 MiB swap partition enabled now and persistent at reboot' "$NODE2" "$NODE2_ROOT_PASS" '
set -u
swapon --noheadings --raw --show=NAME,SIZE,TYPE 2>/dev/null | awk "$3 == \"partition\" {n=$2; gsub(/[^0-9]/,\"\",n); if (n >= 240 && n <= 260) found=1} END {exit !found}" || exit 1
# Find a matching swap partition persisted in fstab (UUID or device path).
awk "!/^#/ && \$3 == \"swap\" {found=1} END {exit !found}" /etc/fstab || exit 1
'

run_remote_check Q21 30 'myvol VG (8 MiB PE), 50-PE mydatabase LV, vfat mounted persistently at /database' "$NODE2" "$NODE2_ROOT_PASS" '
set -u
vgs myvol >/dev/null 2>&1 || exit 1
pe=$(vgs --noheadings --units m --nosuffix -o vg_extent_size myvol 2>/dev/null | awk "{print int(\$1+0.5)}")
[[ "$pe" == 8 ]] || exit 1
lvs myvol/mydatabase >/dev/null 2>&1 || exit 1
[[ $(lvs --noheadings -o lv_extent_count myvol/mydatabase 2>/dev/null | tr -d " ") == 50 ]] || exit 1
[[ $(blkid -o value -s TYPE /dev/myvol/mydatabase 2>/dev/null) == vfat ]] || exit 1
findmnt -n -T /database >/dev/null 2>&1 || exit 1
[[ $(findmnt -n -T /database -o FSTYPE) == vfat ]] || exit 1
awk "!/^#/ && \$2 == \"/database\" {found=1} END {exit !found}" /etc/fstab || exit 1
'

run_remote_check Q22 12 '/home LV resized to 125-165 MB and filesystem remains accessible' "$NODE2" "$NODE2_ROOT_PASS" '
set -u
findmnt -n -T /home >/dev/null 2>&1 || exit 1
lv=$(findmnt -n -T /home -o SOURCE 2>/dev/null)
[[ "$lv" == *"/dev/mapper/myvg-home"* || "$lv" == "/dev/myvg/home" ]] || exit 1
size=$(lvs --noheadings --units m --nosuffix -o lv_size /dev/myvg/home 2>/dev/null | awk "{print int(\$1+0.5)}")
[[ -n "$size" ]] && (( size >= 125 && size <= 165 )) || exit 1
'

printf '\n%s%sScore summary%s\n' "$BLUE" "$BOLD" "$RESET"
printf '%-5s | %-6s | %-4s | %s\n' 'Task' 'Result' 'Mark' 'Description'
printf '%s\n' '--------------------------------------------------------------------------'
for item in "${SUMMARY[@]}"; do
  IFS='|' read -r q description result weight <<< "$item"
  if [[ "$result" == PASS ]]; then color="$GREEN"; else color="$RED"; fi
  printf '%-5s | %s%-6s%s | %3s  | %s\n' "$q" "$color" "$result" "$RESET" "$([[ $result == PASS ]] && echo "$weight" || echo 0)/$weight" "$description"
done
percentage=$((TOTAL_EARNED * 100 / TOTAL_MARKS))
printf '%s\n' '--------------------------------------------------------------------------'
printf 'MARKS: %d / %d\nPERCENTAGE: %d%%\nPASS MARKS: %d\n' "$TOTAL_EARNED" "$TOTAL_MARKS" "$percentage" "$PASS_MARKS"
if (( TOTAL_EARNED >= PASS_MARKS )); then
  printf '%s%sRESULT: PASS%s\n' "$GREEN" "$BOLD" "$RESET"
else
  printf '%s%sRESULT: FAIL%s\n' "$RED" "$BOLD" "$RESET"
fi
printf '\nNotes: Password values for ordinary user accounts are not tested by reading /etc/shadow. Q05/Q12 verify account/group/UID state only. Q15 is absent from the supplied HTML files; the root-password task is checked as Q16 on node2, as requested.\n'
