import pya

print("Merging standard cell GDS with neuromorphic_bci_top DEF into true GDSII stream...")
layout = pya.Layout()

# 1. Read standard cell GDS library
gds_lib = "/opt/orfs/flow/platforms/nangate45/gds/NangateOpenCellLibrary.gds"
print(f"Reading library GDS: {gds_lib}")
layout.read(gds_lib)

# 2. Read placed & routed DEF with LEF config
def_file = "/mnt/c/Users/surya/OneDrive/Documents/COLLEGE_RESEARCH/neuromorphic-bci-core/pnr/neuromorphic_bci_top.def"
print(f"Reading routed DEF: {def_file}")
opt = pya.LoadLayoutOptions()
opt.lefdef_config.lef_files = [
    "/opt/orfs/flow/platforms/nangate45/lef/NangateOpenCellLibrary.tech.lef",
    "/opt/orfs/flow/platforms/nangate45/lef/NangateOpenCellLibrary.macro.mod.lef"
]
opt.lefdef_config.read_lef_with_def = True
opt.dbr = 0.0005
layout.read(def_file, opt)

# 3. Write merged GDSII
out_gds = "/mnt/c/Users/surya/OneDrive/Documents/COLLEGE_RESEARCH/neuromorphic-bci-core/pnr/neuromorphic_bci_top.gds"
print(f"Writing final GDSII stream to: {out_gds}")
layout.write(out_gds)
print("neuromorphic_bci_top GDSII generation complete!")
