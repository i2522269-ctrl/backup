import shutil
import glob
import os

def run():
    print("-> Ingestando 6 CSVs locales a data/bronze...")
    source_dir = r"C:\Users\joanz\Downloads\csv-20260319T022238Z-1-001\csv"
    bronze_dir = r"data\bronze"
    csvs = glob.glob(os.path.join(source_dir, "*.csv"))
    for c in csvs:
        shutil.copy(c, bronze_dir)
        print(f"Copiado: {os.path.basename(c)}")
    print("-> Extrayendo datos raw desde la API de Supabase...")
    # Lógica requests.get a supabase/rest/v1/registros_estudiantes
