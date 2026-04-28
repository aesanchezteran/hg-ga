# hg-ga
# A Hardware-Accelerator for Genetic Algorithm Real-Time Optimization

This repository provides a complete hardware–software framework for an FPGA-based implementation of a **hardware-accelerated Genetic Algorithm (HG-GA)** applied to the **non-preemptive multiprocessor scheduling problem**.

The system is implemented on the **Xilinx Kria KV260 platform** and integrates a custom accelerator through an **AXI4-Lite interface**, enabling real-time scheduling optimization.


---

## 📁 Repository Structure

```text
.
├── src/        # SystemVerilog RTL modules (HG-GA core, fitness, selection, control)
├── sim/        # Testbench, tasksets (.svh), and waveform configuration
├── ip_repo/    # Packaged custom AXI IP (HG-GA accelerator)
├── vivado/     # Tcl script to recreate the full Vivado project
├── dataset/    # Python scripts and datasets (JSON + SVH) for task generation/evaluation
├── jupyter/    # Notebooks and overlays for running the accelerator on KRIA (PYNQ)
└── README.md
```

---

## ⚙️ Requirements

- **Vivado 2022.2**
- **Xilinx Kria KV260**
- Python 3.x
- PYNQ environment (for hardware execution)

---

## 🚀 Quick Start (Project Recreation)

You can fully recreate the Vivado project using the provided Tcl script.

### Step 1: Open Vivado
Launch Vivado **without opening any project**.

### Step 2: Run the Tcl script

```tcl
cd <path-to-repo>/vivado
source create_Multiprocessor_GA_KRIA.tcl
launch_runs impl_1 -to_step write_bitstream
```

### What this does
- Creates the Vivado project
- Imports RTL sources from `src/`
- Loads custom IP from `ip_repo/`
- Recreates the block design
- Generates the top-level wrapper

---

## 🔧 Bitstream Generation

To generate the hardware output files, the **complete Vivado design flow must be executed**, including:

1. **Synthesis**
2. **Implementation**
3. **Bitstream generation**

This can be done from the Vivado GUI, or directly from the Tcl console:

```tcl
launch_runs synth_1
wait_on_run synth_1

launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1
```

Once the flow completes successfully, the following files are generated:

- `.bit` → FPGA configuration bitstream  
- `.hwh` → Hardware handoff file used by PYNQ  

These files are required to deploy and interact with the accelerator on the KRIA platform.

---

## 🧪 Simulation

Simulation resources are located in `sim/`:

- `top_tb.sv` → Main testbench  
- `tasksets_300_8.svh` → Tasksets with **0.8 utilization** (300 tasks evaluated)  
- `tasksets_300_9.svh` → Tasksets with **0.9 utilization** (300 tasks evaluated)  
- `tasksets_500.svh` → Tasksets with **0.7 utilization** (500 tasks generated, 300 evaluated)  
- `top_tb_behav.wcfg` → Waveform configuration  

### Taskset Description

Each taskset file corresponds to a different **average processor utilization level**:

- **0.7 utilization** → `tasksets_500.svh`  
  - 500 tasks were generated  
  - Only 300 tasks are evaluated in the simulation  

- **0.8 utilization** → `tasksets_300_8.svh`  
  - 300 tasks evaluated  

- **0.9 utilization** → `tasksets_300_9.svh`  
  - 300 tasks evaluated  

### Running simulation

1. Set `top_tb` as the top module for simulation
2. Ensure the desired `.svh` taskset file is included or referenced by the testbench before running simulation.
3. Run behavioral simulation in Vivado  

---

## 📊 Dataset Generation & Evaluation

The `dataset/` folder contains:

- `DatasetGenerator.py` → Generates tasksets  
- `DatasetEvaluator.py` → Evaluates scheduling performance of EDF, LLF, and EFSB schedulers.

### Output formats:
- `.json` → Used in PYNQ execution  
- `.svh` → Used in RTL simulation  

Tasksets are generated using the UUniFast algorithm to produce task sets with controlled processor utilization levels.

---

## 🧠 Running on KRIA (PYNQ)

The `jupyter/` folder includes:

- Jupyter notebooks to interact with the accelerator  
- Precompiled overlays (`.bit`, `.hwh`)  
- JSON tasksets for testing  

### Setup on KRIA

All files inside the `jupyter/` folder must be copied to a directory accessible from the PYNQ environment on the Kria board (e.g., `/home/xilinx/jupyter_notebooks/`).

The provided `.bit` and `.hwh` files are **precompiled at a 20 MHz clock frequency**.

> ⚠️ If any modification is made to the hardware design (RTL, IP, or block design), the bitstream must be regenerated in Vivado.  
> The newly generated `.bit` and `.hwh` files must then replace the existing ones in the PYNQ directory before running the notebooks.

### Notebook Workflow

1. Load overlay  
2. Interface with the accelerator via MMIO by writing task parameters to AXI registers and triggering execution  
3. Run accelerator  
4. Retrieve results  
5. Evaluate performance  

---

## 🏗️ Hardware Architecture Overview

- Pipelined **HG-GA architecture**
- Parallel fitness evaluation units
- AXI4-Lite interface for PS–PL communication

### AXI Interface (Summary)

- Control register → start signal
- Execution times → input registers (task parameters)
- Deadlines → input registers (task parameters)
- Best schedule → output registers (task-to-processor mapping)
- Fitness → output register (internally computed fitness)

### Fitness Objectives (Hierarchical)
1. **Deadline Misses (DLM)** → hard constraint  
2. Schedule Length  
3. Average Response Time (ART)  
4. Average Turnaround Time (ATAT)  

---

## 📌 Notes

- The project is **fully reproducible** via the Tcl script
- No Vivado-generated folders are required (`.runs`, `.cache`, etc.)
- Ensure `ip_repo/` is present before running the script
- Designed for research and experimental evaluation

---

## 👨‍💻 Author

**David Mendoza**  
Research Assistant – Electronics Engineering Department  
Universidad San Francisco de Quito (USFQ)

**Alberto Sánchez**  
Professor – Electronics Engineering Department  
Universidad San Francisco de Quito (USFQ)


---

## 🚀 Tips

- Always run the Tcl script from the `vivado/` directory  
- If errors occur, verify:
  - paths to `src/`, `sim/`, `ip_repo/`
  - Vivado version compatibility  
- Use a clean directory when testing reproducibility  

---
