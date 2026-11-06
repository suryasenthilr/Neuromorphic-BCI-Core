import re
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

def parse_vcd(filename):
    with open(filename, 'r') as f:
        lines = f.readlines()

    var_map = {}
    data = {}
    time = 0
    in_dumpvars = False

    for line in lines:
        line = line.strip()
        if line.startswith('$var'):
            parts = line.split()
            # $var wire 1 ! clk $end
            # $var wire 8 " aer_addr [3:0] $end
            sig_id = parts[3]
            sig_name = parts[4]
            var_map[sig_id] = sig_name
            data[sig_name] = []
        elif line.startswith('#'):
            try:
                time = int(line[1:])
            except:
                pass
        elif line.startswith('$dumpvars'):
            in_dumpvars = True
        elif line.startswith('$end') and in_dumpvars:
            in_dumpvars = False
        elif line and not line.startswith('$'):
            if line[0] in '01xXzZ':
                val = line[0]
                sig_id = line[1:]
                if sig_id in var_map:
                    sig_name = var_map[sig_id]
                    data[sig_name].append((time, val))
            elif line.startswith('b'):
                parts = line.split()
                val = parts[0][1:]
                sig_id = parts[1]
                if sig_id in var_map:
                    sig_name = var_map[sig_id]
                    data[sig_name].append((time, val))

    return data

import os

base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
vcd_path = os.path.join(base_dir, 'sim', 'dump.vcd')
out_path = os.path.join(base_dir, 'docs', 'images', 'bci_waveform.png')

data = parse_vcd(vcd_path)

# Signals to plot
signals = [
    ('clk', 'Clock (100MHz)', 'digital'),
    ('aer_req', 'AER Request', 'digital'),
    ('aer_ack', 'AER Acknowledge', 'digital'),
    ('aer_addr', 'AER Channel Addr', 'bus'),
    ('spikes_raw', 'Neuron Spike Bus', 'bus'),
    ('decision_valid', 'BCI Decision Valid', 'digital'),
    ('detected_class', 'Decoded Motor Intent', 'bus'),
    ('confidence_count', 'Spike Confidence', 'bus'),
]

plt.style.use('dark_background')
fig, axes = plt.subplots(len(signals), 1, figsize=(14, 9), sharex=True)
fig.suptitle('Neuromorphic BCI Processor - Real-Time Neural Spike Decoding Waveform', fontsize=14, fontweight='bold', color='#38bdf8', y=0.98)

times = np.arange(0, 1750000, 1000) # up to 1.75us in ps

for ax, (sig_key, label, sig_type) in zip(axes, signals):
    sig_data = data.get(sig_key, [])
    if not sig_data:
        # Fallback search
        for k in data.keys():
            if k.lower() == sig_key.lower():
                sig_data = data[k]
                break
    
    t_vals = [0]
    v_vals = [0]
    last_val = 0
    for t, v in sig_data:
        t_vals.append(t)
        try:
            if sig_type == 'digital':
                last_val = 1 if v == '1' else 0
            else:
                last_val = int(v, 2) if set(v).issubset({'0', '1'}) else 0
        except:
            last_val = 0
        v_vals.append(last_val)

    if sig_type == 'digital':
        ax.step(t_vals, v_vals, where='post', color='#00ffcc', linewidth=1.5)
        ax.set_ylim(-0.2, 1.2)
        ax.set_yticks([0, 1])
    else:
        ax.step(t_vals, v_vals, where='post', color='#f59e0b', linewidth=1.5)
        ax.set_ylim(min(v_vals) - 0.5, max(v_vals) + 1.5)
    
    ax.set_ylabel(label, fontsize=9, fontweight='semibold', color='#e2e8f0', rotation=0, labelpad=90, ha='right')
    ax.grid(True, linestyle=':', alpha=0.3, color='#475569')
    ax.tick_params(colors='#94a3b8', labelsize=8)

axes[-1].set_xlabel('Simulation Time (ps)', fontsize=10, color='#94a3b8')
plt.tight_layout(rect=[0, 0.03, 1, 0.95])
plt.savefig(out_path, dpi=200, bbox_inches='tight')
print("Waveform image generated successfully!")
