import pandas as pd
import matplotlib.pyplot as plt
import sys
import os

# NOTE: -- THIS IS VIBE CODED 

# Configuration
FILES = {
    'Simple (AFL)': '../experiment_simple.csv',
    'Boosted': '../experiment_boosted.csv',
    'Fast (AFL++)': '../experiment_fast.csv'
}

def plot_experiment():
    plt.figure(figsize=(12, 8)) # Slightly taller for better visibility
    
    max_total_lines = 0
    
    # Keep track of last points to adjust text positions if needed
    last_points = []

    for label, filename in FILES.items():
        if not os.path.exists(filename):
            print(f"Warning: {filename} not found. Skipping.")
            continue
            
        try:
            # Read CSV
            df = pd.read_csv(filename)
            
            if df.empty:
                print(f"Warning: {filename} is empty.")
                continue

            # Plot (X=Run Count, Y=Coverage)
            # We use 'markevery' to put a marker at the end
            line, = plt.plot(df['run_id'], df['coverage'], label=label, linewidth=2)
            
            # Grab total lines from the first row
            if 'total_lines' in df.columns:
                total = df['total_lines'].iloc[0]
                max_total_lines = max(max_total_lines, total)
                
            # Get the final point
            last_x = df['run_id'].iloc[-1]
            last_y = df['coverage'].iloc[-1]
            
            # --- NEW: Annotate the end of the line ---
            # This puts the text "  <runs>" slightly to the right of the last point
            # matched to the line color
            plt.annotate(
                f'{int(last_x)} runs', 
                xy=(last_x, last_y), 
                xytext=(5, 0),             # 5 points offset to the right
                textcoords='offset points',
                va='center', 
                color=line.get_color(), 
                fontweight='bold',
                fontsize=9
            )
            
            # Add a dot at the end for clarity
            plt.plot(last_x, last_y, 'o', color=line.get_color())

            # Console output
            print(f"{label}: {last_y}/{max_total_lines} lines | {last_x} runs")
            
        except Exception as e:
            print(f"Error reading {filename}: {e}")

    # Plot Theoretical Max Line
    if max_total_lines > 0:
        plt.axhline(y=max_total_lines, color='r', linestyle='--', alpha=0.5, label='Total Instrumented Lines')
        plt.text(0, max_total_lines * 1.01, f' Max: {max_total_lines}', color='r', fontsize=8)

    plt.title('Greybox Fuzzing: Power Schedule Comparison')
    plt.xlabel('Number of Iterations (Throughput)')
    plt.ylabel('Coverage (Line Hits)')
    plt.legend(loc='lower right')
    plt.grid(True, linestyle='--', alpha=0.7)
    
    # Adjust layout to make room for labels on the right
    plt.tight_layout()
    
    output_file = 'experiment_results.png'
    plt.savefig(output_file, dpi=300)
    print(f"\nPlot saved to {output_file}")
    plt.show()

if __name__ == "__main__":
    plot_experiment()