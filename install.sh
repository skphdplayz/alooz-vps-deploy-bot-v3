#!/usr/bin/env bash
# ============================================================
#   ALOOZ HOSTING VPS BOT V5.1 - One-Click Installer + Runner
#   Made by SKPHDGAMER
# ============================================================
set -e

# Create a clean directory if run via curl
mkdir -p alooz-bot && cd alooz-bot
BOT_DIR="$(pwd)"

clear
echo "================================================================"
echo "   ALOOZ HOSTING VPS BOT V5.1 - INSTALLER"
echo "   Made by SKPHDGAMER"
echo "================================================================"
echo ""

# ---------- 1. Python & Dependencies ----------
if ! command -v python3 &>/dev/null; then
    echo "[*] Installing Python 3..."
    sudo apt-get update -qq
    sudo apt-get install -y python3 python3-pip python3-venv sshpass
else
    if ! dpkg -s python3-venv &>/dev/null || ! dpkg -s sshpass &>/dev/null; then
        echo "[*] Installing python3-venv & sshpass..."
        sudo apt-get update -qq
        sudo apt-get install -y python3-venv sshpass
    fi
fi

# ---------- 2. Docker ----------
if ! command -v docker &>/dev/null; then
    echo "[*] Installing Docker..."
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker "$USER" || true
    echo "[!] Docker installed. You may need to log out/in."
fi

if ! sudo docker info &>/dev/null && ! docker info &>/dev/null; then
    echo "[!] Starting Docker daemon..."
    sudo systemctl enable --now docker || sudo service docker start || true
fi

# ---------- 3. requirements.txt ----------
if [ ! -f requirements.txt ]; then
    cat > requirements.txt <<'REQEOF'
discord.py>=2.4.0
python-dotenv>=1.0.0
REQEOF
fi

# ---------- 4. Python packages ----------
echo "[*] Creating virtual environment..."
python3 -m venv venv
source venv/bin/activate
echo "[*] Installing Python packages..."
python3 -m pip install --upgrade pip
python3 -m pip install -r requirements.txt

# ---------- 5. Bot code ----------
if [ ! -f alooz_bot.py ]; then
    echo "[*] Creating alooz_bot.py..."
    cat > alooz_bot.py <<'BOTEOF'
#!/usr/bin/env python3
"""
ALOOZ HOSTING VPS Deploy Bot V5.1
- 70+ working commands
- Full VPS hosting management (A to Z)
- SSHX Web Terminal Integration
- Interactive terminal menu (8 options)
- Startup animation
- Docker-backed VPS manager
"""
import os, sys, re, time, json, sqlite3, secrets, string, asyncio, logging, shutil, platform, subprocess, socket, random, threading
from pathlib import Path
from typing import Optional
import discord
from discord.ext import commands, tasks
from discord import app_commands
from dotenv import load_dotenv

BASE = Path(__file__).resolve().parent
ENV_FILE = BASE / '.env'
DB_FILE = BASE / 'alooz_vps.db'
LOG_FILE = BASE / 'bot.log'

load_dotenv(ENV_FILE)
TOKEN = os.getenv('DISCORD_TOKEN', '').strip()
OWNER_ID = int(os.getenv('OWNER_ID', '0') or 0)
PREFIX = os.getenv('BOT_PREFIX', '!')
PORT_START = int(os.getenv('PORT_START', '20000'))
PORT_END = int(os.getenv('PORT_END', '20999'))
SERVER_IP = os.getenv('SERVER_IP', 'YOUR_SERVER_IP')
MAX_VPS_PER_USER = int(os.getenv('MAX_VPS_PER_USER', '3'))
VERSION = '5.1'
BOT_START = time.time()

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(name)s: %(message)s',
    handlers=[logging.FileHandler(LOG_FILE), logging.StreamHandler()]
)
log = logging.getLogger('alooz')

class C:
    CYAN='\033[96m'; GREEN='\033[92m'; YELLOW='\033[93m'; RED='\033[91m'
    BLUE='\033[94m'; MAGENTA='\033[95m'; BOLD='\033[1m'; RESET='\033[0m'; CLEAR='\033[2J\033[H'

# ==================== STARTUP ANIMATION ====================
def play_startup_animation():
    banner = r"""
    ╔═══════════════════════════════════════════════════════════╗
    ║                                                           ║
    ║      █████╗ ██╗      ██████╗  ██████╗ ███████╗            ║
    ║     ██╔══██╗██║     ██╔═══██╗██╔═══██╗╚══███╔╝            ║
    ║     ███████║██║     ██║   ██║██║   ██║  ███╔╝             ║
    ║     ██╔══██║██║     ██║   ██║██║   ██║ ███╔╝              ║
    ║     ██║  ██║███████╗╚██████╔╝╚██████╔╝███████╗            ║
    ║     ╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝ ╚══════╝            ║
    ║                                                           ║
    ║              H O S T I N G   •   V P S                    ║
    ║                                                           ║
    ╚═══════════════════════════════════════════════════════════╝
    """
    frames = [
        "  [■□□□□□□□□□]  0%   Initializing ALOOZ CORE...",
        "  [■■□□□□□□□□] 20%   Loading Docker Engine...",
        "  [■■■□□□□□□□] 35%   Connecting to Discord API...",
        "  [■■■■■□□□□□] 50%   Mounting VPS database...",
        "  [■■■■■■■□□□] 70%   Loading 70+ commands...",
        "  [■■■■■■■■■□] 90%   Starting SSH port pool...",
        "  [■■■■■■■■■■] 100%  ALOOZ HOSTING ready! 🚀",
    ]
    print(C.CYAN + banner + C.RESET)
    for f in frames:
        print(C.GREEN + f + C.RESET); time.sleep(0.35)
    print(C.YELLOW + "=" * 63)
    print(f"  ALOOZ HOSTING VPS DEPLOY BOT v{VERSION} — Made by SKPHDGAMER")
    print("=" * 63 + C.RESET + "\n")

# ==================== ENV HELPERS ====================
def save_env(values):
    existing = {}
    if ENV_FILE.exists():
        for line in ENV_FILE.read_text().splitlines():
            if '=' in line and not line.strip().startswith('#'):
                k,v = line.split('=',1); existing[k.strip()] = v.strip()
    existing.update(values)
    ENV_FILE.write_text('\n'.join(f'{k}={v}' for k,v in existing.items()) + '\n')

def ask_credentials():
    global TOKEN, OWNER_ID
    print(C.YELLOW + "\n┌─────────────────────────────────────────────┐")
    print("│   ALOOZ HOSTING — FIRST TIME SETUP          │")
    print("└─────────────────────────────────────────────┘" + C.RESET)
    need_t = not TOKEN or len(TOKEN) < 20
    need_o = OWNER_ID <= 0
    if need_t:
        print(C.CYAN + "\n[1/2] Enter Discord Bot Token:" + C.RESET)
        while True:
            tok = input(C.GREEN + "      Token: " + C.RESET).strip()
            if len(tok) < 20: print(C.RED + "      ❌ Too short." + C.RESET); continue
            TOKEN = tok; break
    else: print(C.GREEN + "\n✅ Token already set." + C.RESET)
    if need_o:
        print(C.CYAN + "\n[2/2] Enter Owner Discord ID (numeric):" + C.RESET)
        while True:
            try:
                oid = int(input(C.GREEN + "      Owner ID: " + C.RESET).strip())
                if oid <= 0: raise ValueError
                OWNER_ID = oid; break
            except ValueError: print(C.RED + "      ❌ Invalid." + C.RESET)
    else: print(C.GREEN + "\n✅ Owner ID already set." + C.RESET)
    if need_t or need_o:
        save_env({'DISCORD_TOKEN':TOKEN,'OWNER_ID':str(OWNER_ID),'BOT_PREFIX':PREFIX,
                  'PORT_START':str(PORT_START),'PORT_END':str(PORT_END),
                  'SERVER_IP':SERVER_IP,'MAX_VPS_PER_USER':str(MAX_VPS_PER_USER)})
        print(C.GREEN + "\n✅ Credentials saved." + C.RESET); time.sleep(1)

# ==================== DATABASE ====================
SCHEMA = '''
CREATE TABLE IF NOT EXISTS vps(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    owner_id INTEGER NOT NULL,
    container TEXT UNIQUE NOT NULL,
    ram_mb INTEGER NOT NULL,
    cpu REAL NOT NULL,
    disk_gb INTEGER NOT NULL,
    ssh_port INTEGER UNIQUE NOT NULL,
    password TEXT NOT NULL,
    image TEXT NOT NULL,
    suspended INTEGER DEFAULT 0,
    created INTEGER NOT NULL,
    label TEXT DEFAULT '',
    notes TEXT DEFAULT ''
);
CREATE TABLE IF NOT EXISTS admins(user_id INTEGER PRIMARY KEY, added_by INTEGER NOT NULL, created INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS settings(key TEXT PRIMARY KEY, value TEXT);
CREATE TABLE IF NOT EXISTS logs(id INTEGER PRIMARY KEY AUTOINCREMENT, action TEXT, actor INTEGER, target TEXT, ts INTEGER);
CREATE TABLE IF NOT EXISTS snapshots(id INTEGER PRIMARY KEY AUTOINCREMENT, vps_id INTEGER, name TEXT, created INTEGER);
'''
conn = sqlite3.connect(DB_FILE, check_same_thread=False)
conn.row_factory = sqlite3.Row
conn.executescript(SCHEMA); conn.commit()

def q(sql, args=(), one=False):
    cur = conn.execute(sql, args); rows = cur.fetchall(); conn.commit()
    return (rows[0] if rows else None) if one else rows

def log_action(action, actor, target=""):
    q('INSERT INTO logs(action,actor,target,ts) VALUES(?,?,?,?)', (action,actor,str(target),int(time.time())))

def owner(uid): return OWNER_ID != 0 and uid == OWNER_ID
def admin(uid): return owner(uid) or q('SELECT 1 FROM admins WHERE user_id=?', (uid,), True) is not None
def password(n=20): return ''.join(secrets.choice(string.ascii_letters+string.digits) for _ in range(n))

def run(*args, timeout=120):
    p = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
    if p.returncode: raise RuntimeError((p.stderr or p.stdout or 'Command failed').strip()[-1200:])
    return p.stdout.strip()

def docker_ok():
    try: run('docker','info',timeout=15); return True
    except Exception: return False

def host_stats():
    mem = {}
    try:
        for line in Path('/proc/meminfo').read_text().splitlines():
            k,v=line.split(':',1); mem[k]=int(v.strip().split()[0])
    except Exception: pass
    du=shutil.disk_usage('/')
    try: load=os.getloadavg()
    except Exception: load=(0,0,0)
    return {'cpu':os.cpu_count() or 1,'ram_total':mem.get('MemTotal',0)//1024,
            'ram_free':mem.get('MemAvailable',0)//1024,
            'disk_total':du.total//1024**3,'disk_free':du.free//1024**3,'load':load}

def get_vps(vid): return q('SELECT * FROM vps WHERE id=?', (vid,), True)

def vps_status(name):
    try: return run('docker','inspect','-f','{{.State.Status}}',name,timeout=15) or 'missing'
    except Exception: return 'missing'

def free_port():
    used={r['ssh_port'] for r in q('SELECT ssh_port FROM vps')}
    for p in range(PORT_START, PORT_END+1):
        if p not in used:
            s=socket.socket()
            try: s.bind(('0.0.0.0',p)); s.close(); return p
            except OSError: s.close()
    return None

BOOT = r'''set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq openssh-server sudo curl wget nano htop git net-tools iputils-ping ca-certificates >/dev/null
mkdir -p /run/sshd
PW="$ROOT_PASSWORD"
echo "root:$PW" | chpasswd
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
exec /usr/sbin/sshd -D -e'''

def docker_create(name,image,ram,cpu,disk,port,pw):
    run('docker','run','-d','--name',name,'--hostname',name,
        '--restart','unless-stopped','--memory',f'{ram}m','--memory-swap',f'{ram}m',
        '--cpus',str(cpu),'--pids-limit','2048','-p',f'{port}:22',
        '-e',f'ROOT_PASSWORD={pw}','--label','alooz.vps=1',image,'bash','-lc',BOOT,timeout=900)

def get_stats(name):
    try: return run('docker','stats','--no-stream','--format',
                    'CPU {{.CPUPerc}} | RAM {{.MemUsage}} | NET {{.NetIO}} | PIDS {{.PIDs}}',
                    name,timeout=20)
    except Exception: return 'Stats unavailable.'

# ==================== SSHX SYSTEM (rewritten) ====================
# How it works:
#  - We run a helper script INSIDE the VPS container using `docker exec` (no SSH / sshpass needed).
#  - sshx is installed once, started in the BACKGROUND (so it never blocks), and its output
#    is saved to /root/.sshx.log. We read the full link (including the #key part) from there.
#  - /sshx  -> returns the existing live link (or creates one if none is running)
#  - /resshx -> kills the old session and creates a brand new link
SSHX_RE = re.compile(r'https://sshx\.io/s/[A-Za-z0-9_-]+(?:#[A-Za-z0-9_-]+)?')

SSHX_SCRIPT = r'''
LOG=/root/.sshx.log
FRESH="$1"

sshx_pids() {
  for d in /proc/[0-9]*; do
    if [ "$(cat "$d/comm" 2>/dev/null)" = "sshx" ]; then echo "${d#/proc/}"; fi
  done
}
read_link() {
  [ -s "$LOG" ] || return 1
  sed 's/\x1b\[[0-9;?]*[A-Za-z]//g' "$LOG" | grep -oE 'https://sshx\.io/s/[A-Za-z0-9_-]+(#[A-Za-z0-9_-]+)?' | head -n 1
}

# Reuse a live session unless a fresh one was requested
if [ "$FRESH" != "1" ] && [ -n "$(sshx_pids)" ]; then
  L="$(read_link)"
  if [ -n "$L" ]; then echo "$L"; exit 0; fi
fi

# Stop old sessions
for p in $(sshx_pids); do kill "$p" 2>/dev/null || true; done
sleep 1

# Wait until the VPS finished its first-boot setup (curl installed)
for i in $(seq 1 90); do
  command -v curl >/dev/null 2>&1 && break
  sleep 2
done
command -v curl >/dev/null 2>&1 || { echo "ERR: VPS is still setting up, try again in a minute."; exit 1; }

# Install sshx if missing
if ! command -v sshx >/dev/null 2>&1; then
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64) T=x86_64-unknown-linux-musl ;;
    aarch64|arm64) T=aarch64-unknown-linux-musl ;;
    *) echo "ERR: unsupported CPU architecture $ARCH"; exit 1 ;;
  esac
  cd /tmp
  if curl -fsSL "https://s3.amazonaws.com/sshx/sshx-$T.tar.gz" -o sshx.tgz && tar xzf sshx.tgz sshx 2>/dev/null; then
    install -m 755 sshx /usr/local/bin/sshx
  else
    curl -fsSL https://sshx.io/get | sh >/dev/null 2>&1 || true
    [ -x "$HOME/.sshx/bin/sshx" ] && ln -sf "$HOME/.sshx/bin/sshx" /usr/local/bin/sshx
  fi
  rm -f /tmp/sshx.tgz /tmp/sshx
fi
command -v sshx >/dev/null 2>&1 || { echo "ERR: could not install sshx (VPS has no internet?)."; exit 1; }

# Start in the background (survives after this command ends)
rm -f "$LOG"
nohup setsid sshx </dev/null >"$LOG" 2>&1 &

for i in $(seq 1 40); do
  L="$(read_link)"
  if [ -n "$L" ]; then echo "$L"; exit 0; fi
  sleep 1
done
echo "ERR: sshx did not return a link."
exit 1
'''

def _sshx_sync(container, fresh):
    out = run('docker', 'exec', container, 'bash', '-c', SSHX_SCRIPT, 'sshx', '1' if fresh else '0', timeout=240)
    m = SSHX_RE.search(out)
    if not m: raise RuntimeError(out.strip() or 'No SSHX link returned.')
    return m.group(0)

async def get_sshx_link(container, fresh=False):
    """Returns the SSHX link, or raises RuntimeError with a readable reason."""
    try:
        return await asyncio.to_thread(_sshx_sync, container, fresh)
    except RuntimeError as e:
        log.error('SSHX error: %s', e)
        raise RuntimeError(str(e).replace('ERR: ', '')[:300])
    except Exception as e:
        log.error('SSHX error: %s', e)
        raise RuntimeError('SSHX failed. Check bot.log.')

def embed_vps(r, secret=False, sshx=None):
    st=vps_status(r['container'])
    e=discord.Embed(title=f'ALOOZ HOSTING • VPS #{r["id"]}',
                    color=discord.Color.green() if st=='running' else discord.Color.orange())
    e.add_field(name='Status', value=('🟢 ' if st=='running' else '🔴 ')+st, inline=True)
    e.add_field(name='Owner', value=f'<@{r["owner_id"]}>', inline=True)
    e.add_field(name='Resources',
                value=f'RAM: {r["ram_mb"]} MB\nCPU: {r["cpu"]} core\nDisk plan: {r["disk_gb"]} GB',
                inline=True)
    e.add_field(name='OS image', value=r['image'], inline=True)
    e.add_field(name='SSH', value=f'`ssh root@{SERVER_IP} -p {r["ssh_port"]}`', inline=False)
    if r['label']: e.add_field(name='Label', value=r['label'], inline=False)
    if secret: e.add_field(name='Root password', value=f'||{r["password"]}||', inline=False)
    if sshx: e.add_field(name='SSHX Web Terminal', value=f'[Click to Connect]({sshx})', inline=False)
    if st=='running' and not sshx: e.add_field(name='Live usage', value=get_stats(r['container']), inline=False)
    e.set_footer(text='Made by SKPHDGAMER • ALOOZ HOSTING • v'+VERSION)
    return e

# ==================== DISCORD BOT ====================
intents = discord.Intents.default()
intents.message_content = True
intents.members = True
bot = commands.Bot(command_prefix=commands.when_mentioned_or(PREFIX), intents=intents, help_command=None)

def require_admin():
    async def pred(ctx):
        if not admin(ctx.author.id): raise commands.CheckFailure('Only ALOOZ admins can use this command.')
        return True
    return commands.check(pred)

def require_owner():
    async def pred(ctx):
        if not owner(ctx.author.id): raise commands.CheckFailure('Only the bot owner can use this command.')
        return True
    return commands.check(pred)

async def send(ctx, text=None, embed=None): await ctx.reply(content=text, embed=embed, mention_author=False)
def permitted(uid, r): return admin(uid) or r['owner_id'] == uid

@bot.event
async def on_ready():
    log.info('Ready: %s (%s)', bot.user, bot.user.id)
    try: await bot.tree.sync()
    except Exception: log.exception('Slash sync failed')
    await bot.change_presence(activity=discord.Activity(type=discord.ActivityType.watching,
                                                        name='ALOOZ HOSTING VPS'))
    print(C.GREEN + f"\n✅ Bot logged in as {bot.user} | {len(bot.commands)} commands" + C.RESET)
    if not status_loop.is_running(): status_loop.start()

@bot.event
async def on_command_error(ctx, error):
    if isinstance(error, commands.CommandNotFound): return
    msg = str(error) if isinstance(error,(commands.CheckFailure,commands.BadArgument,
                                            commands.MissingRequiredArgument)) else 'Command failed. Check logs.'
    if not isinstance(error,(commands.CheckFailure,commands.BadArgument,commands.MissingRequiredArgument)):
        log.exception('Prefix command error', exc_info=error)
    await send(ctx, f'❌ {msg}')

@tasks.loop(minutes=5)
async def status_loop():
    try:
        n = q('SELECT COUNT(*) n FROM vps', one=True)['n']
        await bot.change_presence(activity=discord.Activity(type=discord.ActivityType.watching,
                                                            name=f'{n} VPS • ALOOZ HOSTING'))
    except Exception: pass

# ==================== HELP ====================
@bot.hybrid_command(name='commands', aliases=['help'])
async def commands_cmd(ctx):
    e = discord.Embed(title='ALOOZ HOSTING • Commands (70+)', color=discord.Color.blurple())
    e.add_field(name='👤 User (17)',
        value=f'`{PREFIX}myvps` `{PREFIX}vps` `{PREFIX}ssh` `{PREFIX}sshx` `{PREFIX}resshx` `{PREFIX}info` `{PREFIX}stats` `{PREFIX}logs` '
              f'`{PREFIX}start` `{PREFIX}stop` `{PREFIX}restart` `{PREFIX}password` `{PREFIX}myusage` '
              f'`{PREFIX}limitable` `{PREFIX}ping` `{PREFIX}uptime` `{PREFIX}ip` `{PREFIX}serverinfo`', inline=False)
    if admin(ctx.author.id):
        e.add_field(name='🛡️ Admin (30)',
            value=f'`deploy` `listall` `delete` `suspend` `unsuspend` `resize` `exec` `rebuild` '
                  f'`vpsbyuser` `finduser` `bulkstop` `bulkstart` `broadcast` `node` `logsdb` '
                  f'`backup` `restore` `adminlist` `botstatus` `rename` `note` `label` `reinstall` '
                  f'`migrate` `snapshot` `restore-snap` `diskusage` `top` `portcheck` `refreship`', inline=False)
        e.add_field(name='🎁 User+Admin (8)',
            value=f'`rename` `label` `note` `backup` `restore` `stats` `ssh` `vps`', inline=False)
    if owner(ctx.author.id):
        e.add_field(name='👑 Owner (14)',
            value=f'`adminadd` `adminremove` `ownerinfo` `setip` `setprefix` `setmaxvps` '
                  f'`reload` `shutdown` `dbstats` `purge` `eval` `dbquery` `broadcastall` `resetall`', inline=False)
    e.add_field(name='🎲 Fun (6)',
        value=f'`coinflip` `dice` `random` `quote` `8ball` `choose`', inline=False)
    e.set_footer(text='Made by SKPHDGAMER • v'+VERSION)
    await ctx.reply(embed=e, mention_author=False)

# ==================== BASIC ====================
@bot.hybrid_command(name='ping')
async def ping(ctx): await send(ctx, f'🏓 Pong: `{round(bot.latency*1000)} ms`')

@bot.hybrid_command(name='latency')
async def latency(ctx):
    t = time.time(); msg = await ctx.reply('Testing...', mention_author=False)
    diff = (time.time()-t)*1000
    await msg.edit(content=f'📡 Gateway: `{round(bot.latency*1000)} ms` | RTT: `{diff:.0f} ms`')

@bot.hybrid_command(name='uptime')
async def uptime(ctx):
    try:
        with open('/proc/uptime') as f: sec = float(f.read().split()[0])
    except Exception: sec = time.time()-BOT_START
    d,rem = divmod(int(sec),86400); h,rem = divmod(rem,3600); m,s = divmod(rem,60)
    await send(ctx, f'⏱️ Host: `{d}d {h}h {m}m {s}s` | Bot: `{round(bot.latency*1000)}ms`')

@bot.hybrid_command(name='version')
async def version(ctx): await send(ctx, f'📦 ALOOZ HOSTING Bot **v{VERSION}** | SKPHDGAMER')

@bot.hybrid_command(name='invite')
async def invite(ctx):
    await send(ctx, f'🔗 https://discord.com/api/oauth2/authorize?client_id={bot.user.id}&permissions=8&scope=bot%20applications.commands')

@bot.hybrid_command(name='serverinfo')
async def serverinfo(ctx):
    s = host_stats()
    e = discord.Embed(title='🖥️ ALOOZ HOSTING • Server', color=discord.Color.blurple())
    e.add_field(name='CPU', value=f'{s["cpu"]} cores')
    e.add_field(name='RAM', value=f'{s["ram_total"]} MB')
    e.add_field(name='Disk', value=f'{s["disk_total"]} GB')
    e.add_field(name='Platform', value=platform.platform()[:100], inline=False)
    e.add_field(name='IP', value=f'`{SERVER_IP}`')
    e.set_footer(text='SKPHDGAMER')
    await ctx.reply(embed=e, mention_author=False)

@bot.hybrid_command(name='ip')
async def ip_cmd(ctx): await send(ctx, f'🌐 Server IP: `{SERVER_IP}`')

# ==================== FUN ====================
@bot.hybrid_command(name='coinflip')
async def coinflip(ctx): await send(ctx, f'🪙 **{random.choice(["Heads","Tails"])}**')

@bot.hybrid_command(name='dice')
async def dice(ctx, sides: int = 6):
    if sides < 2: return await send(ctx, 'Sides >= 2.')
    await send(ctx, f'🎲 **{random.randint(1,sides)}** (1-{sides})')

@bot.hybrid_command(name='random')
async def random_cmd(ctx, low: int = 1, high: int = 100):
    if low >= high: return await send(ctx, 'Low < high.')
    await send(ctx, f'🔢 **{random.randint(low,high)}**')

@bot.hybrid_command(name='quote')
async def quote(ctx):
    await send(ctx, '💬 ' + random.choice([
        "The cloud is someone else's computer. — ALOOZ",
        "Have you tried turning it off and on? — Every admin",
        "It works on my machine. — Every dev",
        "RAM = disk for speed lovers. — ALOOZ",
        "No place like 127.0.0.1. — ALOOZ",
    ]))

@bot.hybrid_command(name='8ball')
async def eightball(ctx, *, question: str):
    answers = ['Yes ✅','No ❌','Maybe 🤔','Definitely!','Not now','Ask later','Absolutely','Very unlikely','Of course','Never']
    await send(ctx, f'🎱 Q: {question}\nA: **{random.choice(answers)}**')

@bot.hybrid_command(name='choose')
async def choose(ctx, *, options: str):
    opts = [o.strip() for o in options.split('|') if o.strip()]
    if len(opts) < 2: return await send(ctx, 'Use `option1 | option2 | ...`')
    await send(ctx, f'🤔 I choose: **{random.choice(opts)}**')

# ==================== DEPLOY ====================
@bot.hybrid_command(name='deploy')
@require_admin()
@app_commands.describe(member='VPS customer', ram_mb='RAM in MB', cpu='CPU cores',
                       disk_gb='Disk plan in GB', image='ubuntu:22.04 / ubuntu:24.04 / debian:12')
async def deploy(ctx, member: discord.Member, ram_mb: int, cpu: float, disk_gb: int, image: str = 'ubuntu:22.04'):
    if member.bot: return await send(ctx, 'Bots cannot receive VPS.')
    if not (128<=ram_mb<=262144 and 0.1<=cpu<=128 and 1<=disk_gb<=10000):
        return await send(ctx, 'RAM 128-262144 MB, CPU 0.1-128, disk 1-10000 GB.')
    if image not in ('ubuntu:22.04','ubuntu:24.04','debian:12'):
        return await send(ctx, 'Supported: ubuntu:22.04, ubuntu:24.04, debian:12')
    if not docker_ok(): return await send(ctx, 'Docker unavailable.')
    n = q('SELECT COUNT(*) n FROM vps WHERE owner_id=?', (member.id,), one=True)['n']
    if n >= MAX_VPS_PER_USER: return await send(ctx, f'{member.mention} has {n}/{MAX_VPS_PER_USER}.')
    port = free_port()
    if not port: return await send(ctx, 'No free SSH port.')
    pw = password(); name = 'alooz-vps-' + secrets.token_hex(4)
    msg = await ctx.reply('⏳ Creating VPS (few minutes)...', mention_author=False)
    try:
        run('docker','pull',image,timeout=900)
        docker_create(name,image,ram_mb,cpu,disk_gb,port,pw)
        q('INSERT INTO vps(owner_id,container,ram_mb,cpu,disk_gb,ssh_port,password,image,created) VALUES(?,?,?,?,?,?,?,?,?)',
          (member.id,name,ram_mb,cpu,disk_gb,port,pw,image,int(time.time())))
        row = get_vps(q('SELECT last_insert_rowid() AS id', one=True)['id'])
        log_action('deploy', ctx.author.id, name)
        
        await msg.edit(content='🔗 Generating SSHX Web Terminal Link...')
        try: sshx = await get_sshx_link(name, fresh=True)
        except Exception: sshx = None

        try: await member.send('🎉 VPS ready!', embed=embed_vps(row, True, sshx))
        except discord.Forbidden: pass
        await msg.edit(content=f'✅ Deployed for {member.mention}.', embed=embed_vps(row, True, sshx))
    except Exception as ex:
        log.exception('Deploy failed')
        try: run('docker','rm','-f',name,timeout=30)
        except Exception: pass
        await msg.edit(content=f'❌ `{str(ex)[:700]}`')

# ==================== USER VPS ====================
@bot.hybrid_command(name='myvps')
async def myvps(ctx):
    rows = q('SELECT * FROM vps WHERE owner_id=? ORDER BY id', (ctx.author.id,))
    if not rows: return await send(ctx, 'No VPS.')
    await ctx.reply(embeds=[embed_vps(r) for r in rows[:10]], mention_author=False)

@bot.hybrid_command(name='vps')
async def vps_info(ctx, vps_id: int):
    r = get_vps(vps_id)
    if not r or not permitted(ctx.author.id, r): return await send(ctx, 'Not found/denied.')
    await ctx.reply(embed=embed_vps(r), mention_author=False)

def resolve_vps(ctx, vps_id):
    """vps_id optional: if the user owns exactly one VPS it is picked automatically."""
    if vps_id is None:
        rows = q('SELECT * FROM vps WHERE owner_id=?', (ctx.author.id,))
        if len(rows) == 1: return rows[0], None
        if not rows: return None, 'You have no VPS. Give a VPS id, e.g. `sshx 1`.'
        return None, 'You have several VPS. Use the id: `' + PREFIX + 'sshx <vps_id>`'
    r = get_vps(vps_id)
    if not r or not permitted(ctx.author.id, r): return None, 'Not found/denied.'
    return r, None

async def sshx_flow(ctx, vps_id, fresh):
    r, err = resolve_vps(ctx, vps_id)
    if err: return await send(ctx, err)
    if r['suspended'] and not admin(ctx.author.id): return await send(ctx, 'VPS suspended.')
    if vps_status(r['container']) != 'running': return await send(ctx, 'VPS is not running. Start it first.')
    # Slash commands: reply is private (ephemeral). Prefix commands: link goes to DM.
    msg = await ctx.reply('🔄 Creating a fresh SSHX link...' if fresh else '🔗 Getting SSHX link...',
                          mention_author=False, ephemeral=True)
    try:
        link = await get_sshx_link(r['container'], fresh=fresh)
    except Exception as ex:
        return await msg.edit(content=f'❌ {ex}')
    log_action('resshx' if fresh else 'sshx', ctx.author.id, r['container'])
    text = f'🖥️ **SSHX Web Terminal • VPS #{r["id"]}**\n{link}\n⚠️ Anyone with this link has full access to the VPS. Do not share it.'
    if ctx.interaction is not None:
        return await msg.edit(content=text)
    try:
        await ctx.author.send(text)
        await msg.edit(content=f'✅ SSHX link for VPS #{r["id"]} sent to your DM.')
    except discord.Forbidden:
        await msg.edit(content=text + '\n(Enable DMs from server members to receive links privately.)')

@bot.hybrid_command(name='sshx')
@app_commands.describe(vps_id='VPS id (optional if you have only one)')
async def sshx_cmd(ctx, vps_id: Optional[int] = None):
    await sshx_flow(ctx, vps_id, fresh=False)

@bot.hybrid_command(name='resshx')
@app_commands.describe(vps_id='VPS id (optional if you have only one)')
async def resshx(ctx, vps_id: Optional[int] = None):
    await sshx_flow(ctx, vps_id, fresh=True)

@bot.hybrid_command(name='ssh')
async def ssh_info(ctx, vps_id: int):
    r = get_vps(vps_id)
    if not r or not permitted(ctx.author.id, r): return await send(ctx, 'Not found/denied.')
    msg = await ctx.reply('🔗 Getting SSHX Web Terminal Link...', mention_author=False)
    sshx = None
    if vps_status(r['container']) == 'running':
        try: sshx = await get_sshx_link(r['container'], fresh=False)
        except Exception: sshx = None
    await msg.edit(content=None, embed=embed_vps(r, True, sshx))

@bot.hybrid_command(name='info')
async def info_cmd(ctx, vps_id: int):
    r = get_vps(vps_id)
    if not r or not permitted(ctx.author.id, r): return await send(ctx, 'Not found/denied.')
    created = time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(r['created']))
    e = discord.Embed(title=f'📋 VPS #{vps_id}', color=discord.Color.blurple())
    e.add_field(name='Container', value=r['container'], inline=False)
    e.add_field(name='Owner', value=f'<@{r["owner_id"]}>')
    e.add_field(name='Image', value=r['image'])
    e.add_field(name='RAM', value=f'{r["ram_mb"]} MB')
    e.add_field(name='CPU', value=f'{r["cpu"]}')
    e.add_field(name='Disk', value=f'{r["disk_gb"]} GB')
    e.add_field(name='Port', value=str(r['ssh_port']))
    e.add_field(name='Suspended', value='Yes' if r['suspended'] else 'No')
    e.add_field(name='Created', value=created, inline=False)
    if r['label']: e.add_field(name='Label', value=r['label'], inline=False)
    if r['notes']: e.add_field(name='Notes', value=r['notes'][:500], inline=False)
    await ctx.reply(embed=e, mention_author=False)

@bot.hybrid_command(name='stats')
async def stats_cmd(ctx, vps_id: int):
    r = get_vps(vps_id)
    if not r or not permitted(ctx.author.id, r): return await send(ctx, 'Not found/denied.')
    if vps_status(r['container']) != 'running': return await send(ctx, 'VPS not running.')
    await send(ctx, f'📊 VPS #{vps_id}: `{get_stats(r["container"])}`')

@bot.hybrid_command(name='logs')
async def logs_cmd(ctx, vps_id: int, lines: int = 30):
    r = get_vps(vps_id)
    if not r or not permitted(ctx.author.id, r): return await send(ctx, 'Not found/denied.')
    try:
        out = run('docker','logs','--tail',str(min(lines,100)),r['container'],timeout=20)
        await send(ctx, f'```\n{(out or "(no logs)")[-1800:]}\n```')
    except Exception as ex: await send(ctx, f'❌ {str(ex)[:400]}')

@bot.hybrid_command(name='myusage')
async def myusage(ctx):
    rows = q('SELECT * FROM vps WHERE owner_id=?', (ctx.author.id,))
    if not rows: return await send(ctx, 'No VPS.')
    ram = sum(r['ram_mb'] for r in rows); cpu = sum(r['cpu'] for r in rows); disk = sum(r['disk_gb'] for r in rows)
    await send(ctx, f'📊 ({len(rows)} VPS)\nRAM: `{ram} MB` | CPU: `{cpu}` | Disk: `{disk} GB`')

@bot.hybrid_command(name='limitable')
async def limitable(ctx):
    rows = q('SELECT * FROM vps WHERE owner_id=?', (ctx.author.id,))
    await send(ctx, f'📈 **{len(rows)}/{MAX_VPS_PER_USER}** VPS')

# ==================== POWER ====================
async def power(ctx, vps_id, action):
    r = get_vps(vps_id)
    if not r or not permitted(ctx.author.id, r): return await send(ctx, 'Not found/denied.')
    if r['suspended'] and not admin(ctx.author.id): return await send(ctx, 'VPS suspended.')
    try:
        if action in ('stop','restart'): run('docker',action,'-t','10',r['container'],timeout=60)
        else: run('docker','start',r['container'],timeout=60)
        log_action(action, ctx.author.id, r['container'])
        await send(ctx, f'✅ VPS #{vps_id}: {action}')
    except Exception as ex: await send(ctx, f'❌ {str(ex)[:500]}')

@bot.hybrid_command(name='start')
async def start(ctx, vps_id: int): await power(ctx, vps_id, 'start')

@bot.hybrid_command(name='stop')
async def stop(ctx, vps_id: int): await power(ctx, vps_id, 'stop')

@bot.hybrid_command(name='restart')
async def restart(ctx, vps_id: int): await power(ctx, vps_id, 'restart')

# ==================== PASSWORD ====================
@bot.hybrid_command(name='password')
async def reset_password(ctx, vps_id: int):
    r = get_vps(vps_id)
    if not r or not permitted(ctx.author.id, r): return await send(ctx, 'Not found/denied.')
    if vps_status(r['container']) != 'running': return await send(ctx, 'Start VPS first.')
    pw = password()
    try:
        run('docker','exec',r['container'],'bash','-lc',f'echo "root:{pw}" | chpasswd',timeout=30)
        q('UPDATE vps SET password=? WHERE id=?', (pw, vps_id))
        log_action('password', ctx.author.id, r['container'])
        await send(ctx, f'🔐 New password for #{vps_id}: ||{pw}||')
    except Exception as ex: await send(ctx, f'❌ {str(ex)[:500]}')

# ==================== ADMIN ====================
@bot.hybrid_command(name='listall')
@require_admin()
async def listall(ctx):
    rows = q('SELECT * FROM vps ORDER BY id')
    if not rows: return await send(ctx, 'No VPS.')
    lines = [f"{'🟢' if vps_status(r['container'])=='running' else '🔴'} **#{r['id']}** <@{r['owner_id']}> • "
             f"{r['ram_mb']}MB/{r['cpu']}CPU/{r['disk_gb']}GB • SSH {r['ssh_port']}" for r in rows]
    await send(ctx, '\n'.join(lines)[:3900])

@bot.hybrid_command(name='delete')
@require_admin()
async def delete(ctx, vps_id: int):
    r = get_vps(vps_id)
    if not r: return await send(ctx, 'Not found.')
    await send(ctx, f'⚠️ Reply `CONFIRM` in 30s to delete VPS #{vps_id}.')
    def check(m): return m.author.id==ctx.author.id and m.channel.id==ctx.channel.id and m.content.strip().upper()=='CONFIRM'
    try: await bot.wait_for('message', check=check, timeout=30)
    except asyncio.TimeoutError: return await send(ctx, 'Cancelled.')
    try:
        run('docker','rm','-f',r['container'],timeout=60)
        q('DELETE FROM vps WHERE id=?', (vps_id,))
        log_action('delete', ctx.author.id, r['container'])
        await send(ctx, f'🗑️ VPS #{vps_id} deleted.')
    except Exception as ex: await send(ctx, f'❌ {str(ex)[:500]}')

@bot.hybrid_command(name='suspend')
@require_admin()
async def suspend(ctx, vps_id: int):
    r = get_vps(vps_id)
    if not r: return await send(ctx, 'Not found.')
    try:
        run('docker','stop','-t','10',r['container'])
        q('UPDATE vps SET suspended=1 WHERE id=?', (vps_id,))
        log_action('suspend', ctx.author.id, r['container'])
        await send(ctx, f'⛔ #{vps_id} suspended.')
    except Exception as ex: await send(ctx, str(ex)[:500])

@bot.hybrid_command(name='unsuspend')
@require_admin()
async def unsuspend(ctx, vps_id: int):
    r = get_vps(vps_id)
    if not r: return await send(ctx, 'Not found.')
    try:
        run('docker','start',r['container'])
        q('UPDATE vps SET suspended=0 WHERE id=?', (vps_id,))
        log_action('unsuspend', ctx.author.id, r['container'])
        await send(ctx, f'✅ #{vps_id} unsuspended.')
    except Exception as ex: await send(ctx, str(ex)[:500])

@bot.hybrid_command(name='resize')
@require_admin()
async def resize(ctx, vps_id: int, ram_mb: int, cpu: float):
    r = get_vps(vps_id)
    if not r: return await send(ctx, 'Not found.')
    if not (128<=ram_mb<=262144 and 0.1<=cpu<=128): return await send(ctx, 'Out of range.')
    try:
        run('docker','update','--memory',f'{ram_mb}m','--memory-swap',f'{ram_mb}m','--cpus',str(cpu),r['container'])
        q('UPDATE vps SET ram_mb=?,cpu=? WHERE id=?', (ram_mb, cpu, vps_id))
        log_action('resize', ctx.author.id, r['container'])
        await send(ctx, f'✅ #{vps_id} resized: {ram_mb} MB, {cpu} CPU.')
    except Exception as ex: await send(ctx, f'❌ {str(ex)[:500]}')

@bot.hybrid_command(name='exec')
@require_admin()
async def exec_cmd(ctx, vps_id: int, *, command: str):
    r = get_vps(vps_id)
    if not r: return await send(ctx, 'Not found.')
    try:
        out = run('docker','exec',r['container'],'bash','-lc',command,timeout=60)
        await send(ctx, f'```\n{(out or "(no output)")[-1800:]}\n```')
    except Exception as ex: await send(ctx, f'❌ `{str(ex)[:500]}`')

@bot.hybrid_command(name='rebuild')
@require_admin()
async def rebuild(ctx, vps_id: int):
    r = get_vps(vps_id)
    if not r: return await send(ctx, 'Not found.')
    await send(ctx, f'⚠️ Reply `CONFIRM` to rebuild VPS #{vps_id}.')
    def check(m): return m.author.id==ctx.author.id and m.channel.id==ctx.channel.id and m.content.strip().upper()=='CONFIRM'
    try: await bot.wait_for('message', check=check, timeout=30)
    except asyncio.TimeoutError: return await send(ctx, 'Cancelled.')
    try:
        run('docker','rm','-f',r['container'],timeout=60)
        pw = password()
        docker_create(r['container'], r['image'], r['ram_mb'], r['cpu'], r['disk_gb'], r['ssh_port'], pw)
        q('UPDATE vps SET password=? WHERE id=?', (pw, vps_id))
        log_action('rebuild', ctx.author.id, r['container'])
        await send(ctx, f'♻️ #{vps_id} rebuilt. PW: ||{pw}||')
    except Exception as ex: await send(ctx, f'❌ {str(ex)[:500]}')

@bot.hybrid_command(name='vpsbyuser')
@require_admin()
async def vpsbyuser(ctx, member: discord.Member):
    rows = q('SELECT * FROM vps WHERE owner_id=? ORDER BY id', (member.id,))
    if not rows: return await send(ctx, f'{member.mention} no VPS.')
    lines = [f"**#{r['id']}** • {r['ram_mb']}MB/{r['cpu']}CPU • {vps_status(r['container'])}" for r in rows]
    await send(ctx, '\n'.join(lines)[:3900])

@bot.hybrid_command(name='finduser')
@require_admin()
async def finduser(ctx, member: discord.Member):
    rows = q('SELECT * FROM vps WHERE owner_id=?', (member.id,))
    if not rows: return await send(ctx, f'{member.mention} no VPS.')
    await ctx.reply(embeds=[embed_vps(r) for r in rows[:10]], mention_author=False)

@bot.hybrid_command(name='bulkstop')
@require_admin()
async def bulkstop(ctx):
    rows = q('SELECT * FROM vps')
    count = 0
    for r in rows:
        try: run('docker','stop','-t','5',r['container'],timeout=30); count += 1
        except Exception: pass
    await send(ctx, f'⏹️ Stopped **{count}/{len(rows)}**')

@bot.hybrid_command(name='bulkstart')
@require_admin()
async def bulkstart(ctx):
    rows = q('SELECT * FROM vps WHERE suspended=0')
    count = 0
    for r in rows:
        try: run('docker','start',r['container'],timeout=30); count += 1
        except Exception: pass
    await send(ctx, f'▶️ Started **{count}/{len(rows)}**')

@bot.hybrid_command(name='broadcast')
@require_admin()
async def broadcast(ctx, *, message: str):
    rows = q('SELECT DISTINCT owner_id FROM vps')
    sent = 0
    for r in rows:
        try:
            u = await bot.fetch_user(r['owner_id'])
            await u.send(f'📢 **ALOOZ HOSTING**\n{message}')
            sent += 1
        except Exception: pass
    await send(ctx, f'📢 Sent **{sent}/{len(rows)}**')

@bot.hybrid_command(name='node')
@require_admin()
async def node(ctx):
    s = host_stats()
    t = q('SELECT COUNT(*) n,COALESCE(SUM(ram_mb),0) ram,COALESCE(SUM(cpu),0) cpu,COALESCE(SUM(disk_gb),0) disk FROM vps', one=True)
    e = discord.Embed(title='ALOOZ HOSTING • Node', color=discord.Color.blurple())
    e.add_field(name='CPU', value=f"{s['cpu']} cores\nLoad: {s['load'][0]:.2f}")
    e.add_field(name='RAM', value=f"{s['ram_total']-s['ram_free']}/{s['ram_total']} MB")
    e.add_field(name='Disk', value=f"{s['disk_total']-s['disk_free']}/{s['disk_total']} GB")
    e.add_field(name='VPS', value=f"{t['n']} | {t['ram']} MB | {t['cpu']} CPU | {t['disk']} GB", inline=False)
    e.add_field(name='Docker', value='🟢' if docker_ok() else '🔴')
    await ctx.reply(embed=e, mention_author=False)

@bot.hybrid_command(name='dbstats')
@require_owner()
async def dbstats(ctx):
    v = q('SELECT COUNT(*) n FROM vps', one=True)['n']
    a = q('SELECT COUNT(*) n FROM admins', one=True)['n']
    l = q('SELECT COUNT(*) n FROM logs', one=True)['n']
    s = q('SELECT COUNT(*) n FROM snapshots', one=True)['n']
    sz = DB_FILE.stat().st_size/1024 if DB_FILE.exists() else 0
    await send(ctx, f'🗄️ VPS:`{v}` Admins:`{a}` Logs:`{l}` Snapshots:`{s}` Size:`{sz:.1f}KB`')

@bot.hybrid_command(name='logsdb')
@require_admin()
async def logsdb(ctx, limit: int = 15):
    rows = q('SELECT * FROM logs ORDER BY id DESC LIMIT ?', (min(limit,50),))
    if not rows: return await send(ctx, 'No logs.')
    lines = [f"`{time.strftime('%m-%d %H:%M', time.localtime(r['ts']))}` **{r['action']}** by <@{r['actor']}> → {r['target']}" for r in rows]
    await send(ctx, '\n'.join(lines)[:3900])

@bot.hybrid_command(name='backup')
@require_admin()
async def backup(ctx):
    try:
        data = {'vps': [dict(r) for r in q('SELECT * FROM vps')],
                'admins': [dict(r) for r in q('SELECT * FROM admins')],
                'ts': int(time.time())}
        f = BASE / f'backup_{int(time.time())}.json'
        f.write_text(json.dumps(data, indent=2))
        await send(ctx, f'💾 `{f.name}`')
    except Exception as ex: await send(ctx, f'❌ {str(ex)[:400]}')

# ==================== NEW UNIQUE FEATURES ====================
@bot.hybrid_command(name='rename')
async def rename(ctx, vps_id: int, *, label: str):
    r = get_vps(vps_id)
    if not r or not permitted(ctx.author.id, r): return await send(ctx, 'Not found/denied.')
    q('UPDATE vps SET label=? WHERE id=?', (label[:80], vps_id))
    await send(ctx, f'✅ #{vps_id} renamed to **{label[:80]}**')

@bot.hybrid_command(name='label')
async def label(ctx, vps_id: int, *, label: str):
    r = get_vps(vps_id)
    if not r or not permitted(ctx.author.id, r): return await send(ctx, 'Not found/denied.')
    q('UPDATE vps SET label=? WHERE id=?', (label[:80], vps_id))
    await send(ctx, f'🏷️ #{vps_id} labeled: **{label[:80]}**')

@bot.hybrid_command(name='note')
async def note(ctx, vps_id: int, *, text: str):
    r = get_vps(vps_id)
    if not r or not permitted(ctx.author.id, r): return await send(ctx, 'Not found/denied.')
    q('UPDATE vps SET notes=? WHERE id=?', (text[:2000], vps_id))
    await send(ctx, f'📝 Note saved for #{vps_id}')

@bot.hybrid_command(name='snapshot')
@require_admin()
async def snapshot(ctx, vps_id: int, name: str = ''):
    r = get_vps(vps_id)
    if not r: return await send(ctx, 'Not found.')
    img = f'alooz-snap-{vps_id}-{int(time.time())}'
    try:
        run('docker','commit',r['container'],img,timeout=120)
        q('INSERT INTO snapshots(vps_id,name,created) VALUES(?,?,?)', (vps_id, name or img, int(time.time())))
        await send(ctx, f'📸 Snapshot: `{img}`')
    except Exception as ex: await send(ctx, f'❌ {str(ex)[:500]}')

@bot.hybrid_command(name='diskusage')
@require_admin()
async def diskusage(ctx):
    try:
        out = run('du','-sh',str(DB_FILE.parent),timeout=20)
        await send(ctx, f'💿 Bot dir: `{out}`')
    except Exception as ex: await send(ctx, f'❌ {str(ex)[:400]}')

@bot.hybrid_command(name='top')
@require_admin()
async def top_cmd(ctx):
    try:
        out = run('sh','-c','ps aux --sort=-%cpu | head -n 8',timeout=15)
        await send(ctx, f'```\n{out[:1800]}\n```')
    except Exception as ex: await send(ctx, f'❌ {str(ex)[:400]}')

@bot.hybrid_command(name='portcheck')
@require_admin()
async def portcheck(ctx, port: int):
    if not (1 <= port <= 65535): return await send(ctx, 'Port 1-65535.')
    s = socket.socket()
    try:
        s.bind(('0.0.0.0', port)); s.close(); await send(ctx, f'✅ Port `{port}` free')
    except OSError:
        await send(ctx, f'❌ Port `{port}` in use')

@bot.hybrid_command(name='refreship')
@require_admin()
async def refreship(ctx):
    try:
        out = run('sh','-c',"curl -s ifconfig.me || curl -s icanhazip.com",timeout=20)
        await send(ctx, f'🌐 Public IP: `{out.strip()}`')
    except Exception as ex: await send(ctx, f'❌ {str(ex)[:400]}')

@bot.hybrid_command(name='migrate')
@require_admin()
async def migrate(ctx, vps_id: int):
    r = get_vps(vps_id)
    if not r: return await send(ctx, 'Not found.')
    await send(ctx, f'⚠️ Reply `CONFIRM` to migrate container (recreate).')
    def check(m): return m.author.id==ctx.author.id and m.channel.id==ctx.channel.id and m.content.strip().upper()=='CONFIRM'
    try: await bot.wait_for('message', check=check, timeout=30)
    except asyncio.TimeoutError: return await send(ctx, 'Cancelled.')
    try:
        run('docker','rm','-f',r['container'],timeout=60)
        docker_create(r['container'], r['image'], r['ram_mb'], r['cpu'], r['disk_gb'], r['ssh_port'], r['password'])
        await send(ctx, f'♻️ #{vps_id} migrated.')
    except Exception as ex: await send(ctx, f'❌ {str(ex)[:500]}')

@bot.hybrid_command(name='reinstall')
@require_admin()
async def reinstall(ctx, vps_id: int):
    r = get_vps(vps_id)
    if not r: return await send(ctx, 'Not found.')
    await send(ctx, f'⚠️ Reply `CONFIRM` to reinstall OS.')
    def check(m): return m.author.id==ctx.author.id and m.channel.id==ctx.channel.id and m.content.strip().upper()=='CONFIRM'
    try: await bot.wait_for('message', check=check, timeout=30)
    except asyncio.TimeoutError: return await send(ctx, 'Cancelled.')
    try:
        run('docker','rm','-f',r['container'],timeout=60)
        pw = password()
        docker_create(r['container'], r['image'], r['ram_mb'], r['cpu'], r['disk_gb'], r['ssh_port'], pw)
        q('UPDATE vps SET password=? WHERE id=?', (pw, vps_id))
        await send(ctx, f'🔄 #{vps_id} reinstalled. PW: ||{pw}||')
    except Exception as ex: await send(ctx, f'❌ {str(ex)[:500]}')

@bot.hybrid_command(name='restore-snap')
@require_admin()
async def restore_snap(ctx, vps_id: int):
    snaps = q('SELECT * FROM snapshots WHERE vps_id=? ORDER BY id DESC', (vps_id,))
    if not snaps: return await send(ctx, 'No snapshots.')
    names = '\n'.join(f"`{s['id']}` {s['name']}" for s in snaps[:10])
    await send(ctx, f'📸 Snapshots for #{vps_id}:\n{names}')

# ==================== ADMIN MGMT ====================
@bot.hybrid_command(name='adminadd')
@require_owner()
async def adminadd(ctx, member: discord.Member):
    if member.bot or owner(member.id): return await send(ctx, 'Invalid.')
    try:
        q('INSERT INTO admins(user_id,added_by,created) VALUES(?,?,?)', (member.id, ctx.author.id, int(time.time())))
        await send(ctx, f'✅ {member.mention} admin.')
    except sqlite3.IntegrityError: await send(ctx, 'Already admin.')

@bot.hybrid_command(name='adminremove')
@require_owner()
async def adminremove(ctx, member: discord.Member):
    if owner(member.id): return await send(ctx, 'Cannot remove owner.')
    existed = q('SELECT 1 FROM admins WHERE user_id=?', (member.id,), one=True) is not None
    q('DELETE FROM admins WHERE user_id=?', (member.id,))
    await send(ctx, '✅ Removed.' if existed else 'Not admin.')

@bot.hybrid_command(name='adminlist')
@require_admin()
async def adminlist(ctx):
    ids = [r['user_id'] for r in q('SELECT user_id FROM admins ORDER BY created')]
    await send(ctx, '**Owner:** ' + (f'<@{OWNER_ID}>' if OWNER_ID else '?') +
               '\n**Admins:** ' + (', '.join(f'<@{i}>' for i in ids) if ids else 'None'))

@bot.hybrid_command(name='ownerinfo')
@require_owner()
async def ownerinfo(ctx): await send(ctx, f'Owner ID: `{OWNER_ID}`')

@bot.hybrid_command(name='setip')
@require_owner()
async def setip(ctx, *, ip: str):
    global SERVER_IP
    SERVER_IP = ip
    q('INSERT OR REPLACE INTO settings(key,value) VALUES(?,?)', ('SERVER_IP', ip))
    save_env({'SERVER_IP': ip})
    await send(ctx, f'✅ IP: `{ip}`')

@bot.hybrid_command(name='setprefix')
@require_owner()
async def setprefix(ctx, prefix: str):
    global PREFIX
    PREFIX = prefix
    q('INSERT OR REPLACE INTO settings(key,value) VALUES(?,?)', ('PREFIX', prefix))
    save_env({'BOT_PREFIX': prefix})
    bot.command_prefix = commands.when_mentioned_or(prefix)
    await send(ctx, f'✅ Prefix: `{prefix}`')

@bot.hybrid_command(name='setmaxvps')
@require_owner()
async def setmaxvps(ctx, n: int):
    global MAX_VPS_PER_USER
    if n < 1: return await send(ctx, '>= 1.')
    MAX_VPS_PER_USER = n
    q('INSERT OR REPLACE INTO settings(key,value) VALUES(?,?)', ('MAX_VPS_PER_USER', str(n)))
    save_env({'MAX_VPS_PER_USER': str(n)})
    await send(ctx, f'✅ Max: `{n}`')

@bot.hybrid_command(name='reload')
@require_owner()
async def reload_cmd(ctx):
    await bot.tree.sync(); await send(ctx, '🔄 Slash reloaded.')

@bot.hybrid_command(name='shutdown')
@require_owner()
async def shutdown(ctx):
    await send(ctx, '🛑 Shutting down...'); await bot.close()

@bot.hybrid_command(name='purge')
@require_owner()
async def purge(ctx, limit: int = 10):
    if not ctx.channel.permissions_for(ctx.me).manage_messages: return await send(ctx, 'Missing permission.')
    await ctx.channel.purge(limit=min(limit,100))
    await send(ctx, f'🧹 Purged {limit}')

@bot.hybrid_command(name='eval')
@require_owner()
async def eval_cmd(ctx, *, code: str):
    try:
        result = eval(code, {'bot':bot,'q':q,'run':run,'os':os})
        await send(ctx, f'```\n{str(result)[:1800]}\n```')
    except Exception as ex: await send(ctx, f'❌ `{str(ex)[:500]}`')

@bot.hybrid_command(name='dbquery')
@require_owner()
async def dbquery(ctx, *, sql: str):
    try:
        rows = q(sql)
        out = '\n'.join(str(dict(r)) for r in rows[:20])
        await send(ctx, f'```\n{out[:1800] or "(empty)"}\n```')
    except Exception as ex: await send(ctx, f'❌ `{str(ex)[:500]}`')

@bot.hybrid_command(name='broadcastall')
@require_owner()
async def broadcastall(ctx, *, message: str):
    count = 0
    for guild in bot.guilds:
        for ch in guild.text_channels[:1]:
            try: await ch.send(f'📢 **ALOOZ HOSTING**\n{message}'); count += 1
            except Exception: pass
    await send(ctx, f'📢 {count} channels')

@bot.hybrid_command(name='resetall')
@require_owner()
async def resetall(ctx):
    await send(ctx, '⚠️ Reply `DELETE-ALL` to wipe DB (not containers).')
    def check(m): return m.author.id==ctx.author.id and m.content.strip()=='DELETE-ALL'
    try: await bot.wait_for('message', check=check, timeout=30)
    except asyncio.TimeoutError: return await send(ctx, 'Cancelled.')
    q('DELETE FROM vps'); q('DELETE FROM admins'); q('DELETE FROM logs'); q('DELETE FROM snapshots')
    await send(ctx, '🗑️ DB wiped.')

@bot.hybrid_command(name='botstatus')
@require_admin()
async def botstatus(ctx):
    e = discord.Embed(title='ALOOZ HOSTING • Bot Status', color=discord.Color.green())
    e.add_field(name='Discord', value='✅')
    e.add_field(name='Latency', value=f'{bot.latency*1000:.0f} ms')
    e.add_field(name='Python', value=platform.python_version())
    e.add_field(name='Host', value=platform.node())
    e.add_field(name='DB', value='SQLite')
    e.add_field(name='Docker', value='🟢' if docker_ok() else '🔴')
    e.add_field(name='Commands', value=str(len(bot.commands)))
    await ctx.reply(embed=e, mention_author=False)

# ==================== TERMINAL MENU ====================
def show_menu():
    print(C.CLEAR + C.CYAN + C.BOLD + """
╔═══════════════════════════════════════════════════════════╗
║       ALOOZ HOSTING — MANAGEMENT MENU v5.1                ║
╠═══════════════════════════════════════════════════════════╣
║  1. Reset Bot Token and Owner ID                          ║
║  2. Bot Logs                                              ║
║  3. Update Bot                                            ║
║  4. All Resources                                         ║
║  5. Bot Status                                            ║
║  6. Uninstall Bot                                         ║
║  7. Reinstall Bot                                         ║
║  8. Exit                                                  ║
╚═══════════════════════════════════════════════════════════╝""" + C.RESET)

def menu_reset_credentials():
    global TOKEN, OWNER_ID
    print(C.CYAN + "\n── Reset Credentials ──" + C.RESET)
    tok = input("New Token (blank=keep): ").strip()
    if tok:
        if len(tok) < 20: print(C.RED + "❌ Too short." + C.RESET); return
        TOKEN = tok
    oid_str = input("New Owner ID (blank=keep): ").strip()
    if oid_str:
        try:
            oid = int(oid_str)
            if oid <= 0: raise ValueError
            OWNER_ID = oid
        except ValueError: print(C.RED + "❌ Invalid." + C.RESET); return
    save_env({'DISCORD_TOKEN':TOKEN,'OWNER_ID':str(OWNER_ID)})
    print(C.GREEN + "✅ Saved. Restart bot (option 7)." + C.RESET)

def menu_show_logs(lines=30):
    print(C.CYAN + f"\n── Last {lines} log lines ──" + C.RESET)
    if not LOG_FILE.exists(): print(C.YELLOW + "(no log file)" + C.RESET); return
    try:
        for line in LOG_FILE.read_text(errors='replace').splitlines()[-lines:]: print(line)
    except Exception as ex: print(C.RED + f"❌ {ex}" + C.RESET)

def menu_update_bot():
    print(C.CYAN + "\n── Update Bot ──" + C.RESET)
    try:
        if (BASE / '.git').exists() and shutil.which('git'):
            print("git pull...")
            p = subprocess.run(['git','pull'], cwd=str(BASE), capture_output=True, text=True, timeout=120)
            print(p.stdout or p.stderr)
        print("pip upgrade...")
        subprocess.run([sys.executable,'-m','pip','install','--upgrade','-r',str(BASE/'requirements.txt')], timeout=300)
        print(C.GREEN + "✅ Updated. Restart (option 7)." + C.RESET)
    except Exception as ex: print(C.RED + f"❌ {ex}" + C.RESET)

def menu_all_resources():
    print(C.CYAN + "\n── All Resources ──" + C.RESET)
    s = host_stats()
    print(f"CPU cores       : {s['cpu']}")
    print(f"Load            : {s['load'][0]:.2f} / {s['load'][1]:.2f} / {s['load'][2]:.2f}")
    print(f"RAM total/free  : {s['ram_total']} / {s['ram_free']} MB")
    print(f"Disk total/free : {s['disk_total']} / {s['disk_free']} GB")
    print(f"Docker          : {'🟢' if docker_ok() else '🔴'}")
    print(f"Host            : {platform.node()} ({platform.platform()[:80]})")
    t = q('SELECT COUNT(*) n,COALESCE(SUM(ram_mb),0) ram,COALESCE(SUM(cpu),0) cpu,COALESCE(SUM(disk_gb),0) disk FROM vps', one=True)
    print(f"VPS count       : {t['n']}")
    print(f"VPS allocated   : {t['ram']} MB | {t['cpu']} CPU | {t['disk']} GB")
    print(f"Admins          : {q('SELECT COUNT(*) n FROM admins', one=True)['n']}")
    if DB_FILE.exists(): print(f"DB size         : {DB_FILE.stat().st_size/1024:.1f} KB")

def menu_bot_status():
    print(C.CYAN + "\n── Bot Status ──" + C.RESET)
    running = bot.is_ready() and not bot.is_closed()
    print(f"Running       : {'🟢 Yes' if running else '🔴 No'}")
    print(f"Token         : {'✅' if TOKEN else '❌'}")
    print(f"Owner ID      : {OWNER_ID if OWNER_ID else '❌'}")
    print(f"Bot user      : {bot.user if running else '(n/a)'}")
    print(f"Latency       : {bot.latency*1000:.0f} ms" if running else "Latency       : N/A")
    print(f"Prefix        : {PREFIX}")
    print(f"Server IP     : {SERVER_IP}")
    print(f"Max VPS/user  : {MAX_VPS_PER_USER}")
    print(f"Uptime        : {int(time.time()-BOT_START)}s")
    print(f"Commands      : {len(bot.commands)}")

def menu_uninstall():
    print(C.RED + "\n── Uninstall ──" + C.RESET)
    if input("Type DELETE: ").strip() != 'DELETE':
        print(C.YELLOW + "Cancelled." + C.RESET); return
    try:
        for f in [DB_FILE, LOG_FILE, ENV_FILE]:
            if f.exists(): f.unlink()
        for b in BASE.glob('backup_*.json'): b.unlink()
        print(C.GREEN + "✅ Files removed. Python code remains." + C.RESET)
    except Exception as ex: print(C.RED + f"❌ {ex}" + C.RESET)

def menu_reinstall():
    print(C.CYAN + "\n── Reinstall ──" + C.RESET)
    try:
        subprocess.run([sys.executable,'-m','pip','install','--upgrade','-r',str(BASE/'requirements.txt')], timeout=300)
        print(C.GREEN + "✅ Deps reinstalled. Restart bot manually." + C.RESET)
    except Exception as ex: print(C.RED + f"❌ {ex}" + C.RESET)

# ==================== MAIN ====================
def main():
    play_startup_animation()
    ask_credentials()
    if not TOKEN or OWNER_ID <= 0:
        print(C.RED + "❌ Missing credentials. Use menu option 1." + C.RESET); return
    threading.Thread(target=lambda: bot.run(TOKEN, log_handler=None), daemon=True).start()
    time.sleep(3)
    while True:
        show_menu()
        ch = input(C.GREEN + "\nChoose [1-8]: " + C.RESET).strip()
        if ch == '1': menu_reset_credentials()
        elif ch == '2': menu_show_logs()
        elif ch == '3': menu_update_bot()
        elif ch == '4': menu_all_resources()
        elif ch == '5': menu_bot_status()
        elif ch == '6':
            menu_uninstall()
            if input("Continue? [y/N]: ").strip().lower() != 'y': break
        elif ch == '7': menu_reinstall()
        elif ch == '8':
            print(C.YELLOW + "Bye!" + C.RESET); break
        else: print(C.RED + "Invalid." + C.RESET)
        input(C.YELLOW + "\n[Enter]" + C.RESET)

if __name__ == '__main__':
    try: main()
    except KeyboardInterrupt:
        print(C.YELLOW + "\nInterrupted." + C.RESET)
BOTEOF
    echo "[✓] alooz_bot.py created."
else
    echo "[✓] alooz_bot.py exists."
fi

# ---------- 6. .env ----------
if [ ! -f .env ]; then
    echo ""
    echo "================================================================"
    echo "   FIRST TIME SETUP"
    echo "================================================================"
    read -r -p "Discord Bot Token: " INPUT_TOKEN
    read -r -p "Your Discord Owner ID: " INPUT_OWNER
    read -r -p "Server public IP (blank=unknown): " INPUT_IP
    read -r -p "Bot prefix [default: !]: " INPUT_PREFIX
    INPUT_PREFIX=${INPUT_PREFIX:-!}
    cat > .env <<EOF
DISCORD_TOKEN=${INPUT_TOKEN}
OWNER_ID=${INPUT_OWNER}
BOT_PREFIX=${INPUT_PREFIX}
PORT_START=20000
PORT_END=20999
SERVER_IP=${INPUT_IP:-YOUR_SERVER_IP}
MAX_VPS_PER_USER=3
EOF
    echo "[✓] .env created."
else
    echo "[✓] .env exists."
fi

# ---------- 7. Run ----------
echo ""
echo "================================================================"
echo "   STARTING BOT"
echo "================================================================"
source venv/bin/activate
python3 alooz_bot.py