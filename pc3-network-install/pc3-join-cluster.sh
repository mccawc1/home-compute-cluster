#!/usr/bin/env bash
# pc3-join-cluster.sh <pc3-ip>
# Finish pc3 after the Ubuntu autoinstall and join it to the Ray cluster (head = minipc).
# Run from SER8. Every step is verified; the script stops at the first thing it can't confirm.
set -euo pipefail
IP=${1:?usage: pc3-join-cluster.sh <pc3-ip>}
HEAD=<HEAD_IP>
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -i $HOME/.ssh/pc3 chris@$IP"
T=$(mktemp -d)
step(){ echo; echo "== $*"; }
ok(){ echo "   verified: $*"; }
fail(){ echo "   NOT verified: $*" >&2; exit 1; }

step "1. SSH reachability + identity"
$SSH 'echo "   $(hostname) | $(. /etc/os-release; echo $PRETTY_NAME) | $(nproc) CPU | RAM $(free -h | awk "/^Mem/{print \$2}") | disk $(df -h / | awk "NR==2{print \$2\" (\"\$5\" used)\"}")"' \
  || fail "cannot SSH to chris@$IP with ~/.ssh/pc3"
[ "$($SSH hostname)" = "pc3" ] && ok "hostname is pc3" || fail "hostname is not pc3"

step "2. 'ssh pc3' shortcuts on SER8 and minipc"
grep -q '^Host pc3$' ~/.ssh/config 2>/dev/null || printf '\nHost pc3\n    HostName %s\n    User chris\n    IdentityFile ~/.ssh/pc3\n    IdentitiesOnly yes\n    StrictHostKeyChecking accept-new\n' "$IP" >> ~/.ssh/config
ssh -o BatchMode=yes pc3 true && ok "ssh pc3 works from SER8" || fail "ssh pc3 from SER8"
ssh -o BatchMode=yes minipc "grep -q '^Host pc3\$' ~/.ssh/config 2>/dev/null || printf '\nHost pc3\n    HostName %s\n    User chris\n    IdentityFile ~/.ssh/id_ed25519\n    StrictHostKeyChecking accept-new\n' $IP >> ~/.ssh/config; ssh -o BatchMode=yes pc3 true" \
  && ok "ssh pc3 works from minipc" || fail "ssh pc3 from minipc"

step "3. Firewalls: pc3 trusts the head (minipc) + SER8; minipc trusts pc3"
$SSH "sudo ufw allow OpenSSH >/dev/null; sudo ufw allow from $HEAD comment 'ray head (minipc)' >/dev/null; sudo ufw allow from <DESKTOP_IP> comment 'SER8 eth' >/dev/null; sudo ufw allow from <DESKTOP_IP> comment 'SER8 wifi' >/dev/null; sudo ufw --force enable >/dev/null; sudo ufw status | grep -q '$HEAD'" \
  && ok "pc3 ufw: active, allows minipc + SER8" || fail "pc3 ufw rules"
ssh -o BatchMode=yes minipc "sudo ufw allow from $IP comment 'pc3 (ray worker)' >/dev/null; sudo ufw status | grep -q '$IP'" \
  && ok "minipc ufw allows pc3 ($IP)" || fail "minipc ufw rule for pc3"

step "4. Python 3.12.12 + Ray 2.59.0 on pc3 (must match the other nodes exactly)"
$SSH 'python3 -m venv ~/.venvs/main && ~/.venvs/main/bin/pip install -q uv && UV=~/.venvs/main/bin/uv && $UV python install 3.12.12 -q && $UV venv -q --python 3.12.12 ~/.venvs/ray --allow-existing && VIRTUAL_ENV=~/.venvs/ray $UV pip install -q "ray[default]==2.59.0" && ~/.venvs/ray/bin/python -c "import sys,ray;print(sys.version.split()[0], ray.__version__)"' > "$T/ver" 2>&1 || { cat "$T/ver"; fail "python/ray install"; }
grep -q "3.12.12 2.59.0" "$T/ver" && ok "pc3 has Python 3.12.12 + Ray 2.59.0 (matches SER8 + minipc)" || { cat "$T/ver"; fail "version mismatch"; }

step "5. Ray worker service on pc3 (starts on boot, sized for its RAM)"
CPUS=$($SSH nproc); MEMKB=$($SSH "awk '/MemTotal/{print \$2}' /proc/meminfo")
RAY_MEM=$(( MEMKB*1024 - 700*1024*1024 )); [ "$RAY_MEM" -lt 300000000 ] && RAY_MEM=300000000   # leave ~700 MB for the OS
OBJ=$(( RAY_MEM / 4 )); [ "$OBJ" -lt 100000000 ] && OBJ=100000000
$SSH "mkdir -p ~/.config/systemd/user && cat > ~/.config/systemd/user/ray-worker.service <<EOF
[Unit]
Description=Ray worker (joins minipc Ray cluster)
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=%h/.venvs/ray/bin/ray start --address=$HEAD:6379 --block --node-ip-address=$IP --num-cpus=$CPUS --memory=$RAY_MEM --object-store-memory=$OBJ
ExecStop=%h/.venvs/ray/bin/ray stop
Restart=always
RestartSec=15

[Install]
WantedBy=default.target
EOF
sudo loginctl enable-linger chris && systemctl --user daemon-reload && systemctl --user enable --now ray-worker.service && sleep 12 && systemctl --user is-active ray-worker" \
  && ok "ray-worker active on pc3 ($CPUS CPUs, $((RAY_MEM/1048576)) MB for Ray, $((OBJ/1048576)) MB object store)" || fail "ray-worker service on pc3"

step "6. Head node sees pc3?"
n=0; for i in $(seq 1 12); do n=$(ssh -o BatchMode=yes minipc '~/.venvs/ray/bin/ray status 2>/dev/null | grep -c "^ 1 node_"' || echo 0); [ "${n:-0}" -ge 3 ] && break; sleep 5; done
[ "${n:-0}" -ge 3 ] && ok "ray status on the head shows $n active nodes (SER8 + minipc + pc3)" || fail "head shows ${n:-0} nodes, expected 3"
ssh -o BatchMode=yes minipc '~/.venvs/ray/bin/ray status 2>/dev/null | sed -n "/Total Usage/,/object_store/p"' | sed 's/^/   /'

step "7. Does work actually land on pc3?"
timeout 180 ~/.venvs/ray/bin/python ~/.local/bin/ray-test.py 2>&1 | grep "tasks in" | tee "$T/test" | sed 's/^/   /'
grep -q "'pc3'" "$T/test" && ok "test job ran tasks on pc3" || fail "no tasks ran on pc3"

rm -rf "$T"
echo; echo "pc3 is a verified member of the cluster."
