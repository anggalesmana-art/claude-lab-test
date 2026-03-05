import os
import shutil
import zipfile
import datetime as dt
from datetime import timedelta
import re
import pandas as pd

def process_files(dates_str=None):
    """
    Process files for a given date folder under /data/rpa.
    If no date is provided, uses today's date.
    """

    # --- Input Date Handling ---
    if dates_str:
        try:
            dates = dt.datetime.strptime(dates_str, "%Y-%m-%d").date()
        except ValueError:
            raise ValueError(f"Invalid date format: {dates_str}. Use YYYY-MM-DD.")
    else:
        dates = dt.date.today()
        dates_str = dates.strftime("%Y-%m-%d")

    # --- Derived Variables ---
    year_month = dates.strftime("%Y%m")
    month_name_suffix = year_month
    fixed_suffix = "_" + year_month
    base_path = "/data/rpa"
    destination_path = "/data/gcp/ipos/"
    target_path = os.path.join(base_path, dates_str)

    # --- Ensure destination exists ---
    os.makedirs(destination_path, exist_ok=True)

    # --- Helpers ---
    def is_valid_date(folder_name):
        try:
            dt.datetime.strptime(folder_name, "%Y-%m-%d")
            return True
        except ValueError:
            return False

    def get_max_date_folder(path):
        folders = [
            f for f in os.listdir(path)
            if os.path.isdir(os.path.join(path, f)) and is_valid_date(f)
        ]
        return max(folders) if folders else None

    # def replace_suffix_with_fixed(filename, suffix):
    #     pattern = r"[_-]\d{1,2}[-_][A-Za-z]{3}[-_]\d{4}"
    #     return re.sub(pattern, suffix, filename)
    def replace_suffix_with_fixed(filename, suffix):
        """
        Replaces known date/timestamp suffixes with a fixed suffix (e.g. "_202510").
        Also removes '+06_10_19_UIPATH_AUTO' style segments if present.
        """
        # Replace date-like patterns (e.g. _06-Oct-2024)
        pattern_date = r"([_-]\d{1,2}[-_][A-Za-z]{3}[-_]\d{4})"
        filename = re.sub(pattern_date, suffix, filename)

        # Remove weird "+06_10_19_UIPATH_AUTO" parts
        pattern_plus = r"\+\d{2}_\d{2}_\d{2}_UIPATH_AUTO"
        filename = re.sub(pattern_plus, "", filename)

        return filename

    def copy_and_rename_file(src_path, dst_dir, suffix):
        filename = os.path.basename(src_path)
        new_name = filename.replace("-", "_")
        new_name = replace_suffix_with_fixed(new_name, suffix)
        new_name = re.sub(fr"({suffix})(_.*)(\.xlsx)", r"\1\3", new_name)
        dst_path = os.path.join(dst_dir, new_name)
        shutil.copy2(src_path, dst_path)
        print(f"Copied and renamed: {filename} -> {new_name}")

    def unzip_file_and_rename(zip_path, extract_to, suffix):
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            zip_ref.extractall(extract_to)
        zip_name = os.path.basename(zip_path)
        new_name = zip_name.replace("-", "_")
        new_name = replace_suffix_with_fixed(new_name, suffix)
        renamed_zip_path = os.path.join(destination_path, new_name)
        shutil.copy2(zip_path, renamed_zip_path)
        print(f"Unzipped: {zip_name}")
        print(f"Renamed zip: {zip_name} -> {new_name}")

    def handle_appointment_details(folder, dst_folder, month_suffix):
        app_files = [
            f for f in os.listdir(folder)
            if re.match(r"Appointment_Details_.*\.xlsx$", f, re.IGNORECASE)
        ]
        if len(app_files) == 2:
            print(f"Found 2 Appointment_Details files: {app_files}")
            df_all = pd.concat([
                pd.read_excel(os.path.join(folder, f), engine='openpyxl') for f in app_files
            ], ignore_index=True)

            output_name = f"Appointment_Details_{month_suffix}.xlsx"
            output_path = os.path.join(dst_folder, output_name)
            df_all.to_excel(output_path, index=False)
            print(f"Combined and saved: {output_name}")
        else:
            print(f"Skipping Appointment_Details merge: found {len(app_files)} file(s)")

    # --- Determine folder to use ---
    if os.path.exists(target_path):
        folder = target_path
    else:
        max_folder_name = get_max_date_folder(base_path)
        folder = os.path.join(base_path, max_folder_name) if max_folder_name else None

    # --- Main Logic ---
    if folder:
        print(f"Using folder: {folder}")

        # Step 1: Copy .csv or .xlsx before unzip
        # for file in os.listdir(folder):
        #     if file.lower().endswith((".csv", ".xlsx")):
        #         src_file = os.path.join(folder, file)
        #         copy_and_rename_file(src_file, destination_path, fixed_suffix)

        # Step 2: Unzip and rename .zip files
        for file in os.listdir(folder):
            if file.lower().endswith(".zip"):
                zip_path = os.path.join(folder, file)
                unzip_file_and_rename(zip_path, folder, fixed_suffix)
                handle_appointment_details(folder, destination_path, month_name_suffix)

        # Step 3: Copy .csv or .xlsx again (after unzip)
        for file in os.listdir(folder):
            if file.lower().endswith((".csv", ".xlsx")):
                src_file = os.path.join(folder, file)
                copy_and_rename_file(src_file, destination_path, fixed_suffix)
    else:
        print("No valid folder found.")


# Example for manual run (won’t execute when imported)
if __name__ == "__main__":
    process_files()  # default = today