from pathlib import Path
import hashlib,json,re,sys
root=Path(__file__).resolve().parent.parent
errors=[];count=0
for manifest in sorted(root.glob('*/docs/source_manifest.json')):
    for entry in json.loads(manifest.read_text(encoding='utf-8')):
        p=root/entry['path'];count+=1
        if not p.is_file() or hashlib.sha256(p.read_bytes()).hexdigest()!=entry['sha256']:
            errors.append('Source hash mismatch: '+entry['path'])
for fl in root.glob('*/scripts/files.f'):
    base=fl.parent.parent
    for line in fl.read_text(encoding='utf-8').splitlines():
        if line and not line.startswith('+') and not (base/line).is_file():errors.append('Missing compile input: '+line)
for readme in root.rglob('README.md'):
    for link in re.findall(r'\]\(([^)]+)\)',readme.read_text(encoding='utf-8')):
        if not re.match(r'https?://|#',link) and not (readme.parent/link).exists():errors.append('Broken link: '+str(readme.relative_to(root))+' -> '+link)
groups=[('stopwatch_watch','rtl','top_module_sw_w'),('uart_dht11_sr04','rtl/dht11','TOP_DHT11'),('uart_dht11_sr04','rtl/sr04','lec_sr04_controller'),('uart_dht11_sr04','rtl/uart_fifo','uart_fifo_loopback'),('uart_dht11_sr04','rtl/team_snapshot/stopwatch_watch','top_module_sw_w'),('fifo_uvm','rtl','fifo'),('rv32i_cpu','rtl','rv32i_cpu')]
for project,rtl,top in groups:
    names=[]
    for p in (root/project/rtl).rglob('*'):
        if p.suffix in ('.v','.sv'):
            text=re.sub(r'/\*.*?\*/|//[^\n]*','',p.read_text(encoding='utf-8',errors='replace'),flags=re.S)
            names+=re.findall(r'\bmodule\s+(\w+)',text)
    if top not in names:errors.append('Missing top: '+project+' / '+top)
    duplicate=sorted({n for n in names if names.count(n)>1})
    if duplicate:errors.append('Duplicate RTL modules: '+project+' / '+','.join(duplicate))
for project in ['fifo_uvm','rv32i_cpu']:
    fl=(root/project/'scripts/files.f').read_text(encoding='utf-8')
    tb=[x for x in fl.splitlines() if x.startswith('tb/')]
    if len(tb)!=1:errors.append('Expected one UVM TB: '+project)
if errors:
    print('\n'.join(errors));sys.exit(1)
print(f'PASS: {count} archived files match SHA256; compile inputs, document links, seven RTL top/module sets and single UVM TB selection checked.')
print('Not a synthesis, elaboration, simulation, timing or board test.')
