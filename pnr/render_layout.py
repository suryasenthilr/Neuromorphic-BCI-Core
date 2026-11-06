import os
import pya

def export_layout_image(def_path, lef_paths, lyp_path, output_png, width=2400, height=2400):
    print(f"Loading layout from {def_path}...")
    
    view = pya.LayoutView()
    
    # Configure LEF/DEF reader options
    opt = pya.LoadLayoutOptions()
    opt.lefdef_config.lef_files = lef_paths
    opt.lefdef_config.read_lef_with_def = True
    opt.dbr = 0.0005
    
    # Load DEF into view
    cv_index = view.load_layout(def_path, opt, 1)
    cv = view.cellview(cv_index)
    layout = cv.layout()
    top_cell = layout.top_cell()
    print(f"Loaded design: {top_cell.name}, BBox: {top_cell.bbox()}")
    
    # Load layer properties for colors/styling if available
    if os.path.exists(lyp_path):
        print(f"Loading layer properties: {lyp_path}")
        view.load_layer_props(lyp_path)
    else:
        print("Using default layer properties")
        view.init_layers()
        
    # Fit view to content and show all hierarchy levels
    view.zoom_fit()
    view.max_hier()
    
    # Save high-resolution PNG
    print(f"Saving high-resolution layout rendering to {output_png} ({width}x{height})...")
    view.save_image(output_png, width, height)
    print("Render completed successfully!")

if __name__ == "__main__":
    def_file = "/mnt/c/Users/surya/OneDrive/Documents/COLLEGE_RESEARCH/neuromorphic-bci-core/pnr/neuromorphic_bci_top.def"
    lef_files = [
        "/opt/orfs/flow/platforms/nangate45/lef/NangateOpenCellLibrary.tech.lef",
        "/opt/orfs/flow/platforms/nangate45/lef/NangateOpenCellLibrary.macro.mod.lef"
    ]
    lyp_file = "/opt/orfs/flow/platforms/nangate45/FreePDK45.lyp"
    out_png = "/mnt/c/Users/surya/OneDrive/Documents/COLLEGE_RESEARCH/neuromorphic-bci-core/docs/images/neuromorphic_bci_layout.png"
    
    export_layout_image(def_file, lef_files, lyp_file, out_png, width=2400, height=2400)
