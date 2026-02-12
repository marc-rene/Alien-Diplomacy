"""
Quick little python script to download all addons and LLMs we need because I'm too lazy to click 4 links and
scream at Winodws 11 broken file explorer...
"""

import logging
from pathlib import Path
from urllib.request import urlretrieve
from zipfile import ZipFile
import shutil
import os
import time
from concurrent.futures import ThreadPoolExecutor

Download_hrefs = {
    "LLM 1": "https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf?download=true",
    "LLM 2": "https://huggingface.co/alela32/USER-bge-m3-Q8_0-GGUF/resolve/main/user-bge-m3-q8_0.gguf?download=true",
    "Godot LLM Addon": "https://github.com/nobodywho-ooo/nobodywho/releases/download/nobodywho-godot-v8.0.3/nobodywho-godot-nobodywho-godot-v8.0.3.zip",
}


def download_and_move(
    Href_Key: str, filename: str, is_file: bool, copy_destination: Path, forward=""
):
    abs_filename = Path(Path(__file__).parent / filename).absolute()
    logging.info(f"Downloading {Href_Key}:")
    result = urlretrieve(Download_hrefs[Href_Key], filename=f"{abs_filename}")

    if Path(Href_Key).exists:
        logging.info(f"{Href_Key} saved to: {result[0]}")
    else:
        logging.error(f"{Href_Key} failed to download! CRAP")
        return False

    if is_file:
        try:
            shutil.move(abs_filename, copy_destination.absolute())
        except shutil.Error as E:
            logging.warning(f"HEY! {abs_filename} couldn't be moved because : {E.with_traceback()}")
    else:
        is_zip = Path(filename).suffix.lower() == ".zip"

        # Best not be a damn zip
        logging.info(f"Is a ZIP file? : {is_zip}")

        if is_zip:
            # extraction time
            with ZipFile(Path(abs_filename).absolute(), "r") as current_zip:
                temp_name = Path(Path(__file__).parent / f"temp output ({Href_Key})").absolute()
                logging.info(f"Saving Zip output to {temp_name} for now")
                try:
                    os.makedirs(temp_name)
                except FileExistsError:
                    shutil.rmtree(temp_name)
                    os.makedirs(temp_name)

                # Extracting all to temp
                current_zip.extractall(
                    Path(Path(__file__).parent / temp_name).absolute()
                )
                logging.info(
                    f"Trying to move extracted contents to {copy_destination.absolute()}"
                )

                try:
                    shutil.move(f"{temp_name + forward}", copy_destination)
                    logging.info(
                        f"{temp_name + forward} moved to {copy_destination.absolute()}"
                    )
                    shutil.rmtree(temp_name)
                    current_zip.close()
                except Exception as E:
                    logging.error(f"HEY! There was an error while copying everything over : {E.with_traceback()}")

        else:
            try:
                shutil.move(f"{filename+forward}", copy_destination.absolute())
            except shutil.Error:
                logging.error(f"HEY! {copy_destination.absolute()} already exists!")
                shutil.rmtree(f"{filename+forward}")
    try:
        os.remove(filename)
    except:
        logging.debug(f"Hey, {filename} probably was already deleted")


def start_download(href: str):
    match href:
        case "LLM 1":
            download_and_move(
                href,
                "gemma-2-2b-it-Q4_K_M.gguf",
                is_file=True,
                copy_destination=Path(__file__).parent.parent / "Godot",
            )
        case "LLM 2":
            download_and_move(
                href,
                "user-bge-m3-q8_0.gguf",
                is_file=True,
                copy_destination=Path(__file__).parent.parent / "Godot",
            )
        case "Godot LLM Addon":
            download_and_move(
                href,
                "nobodywho-godot-nobodywho-godot-v8.0.3.zip",
                is_file=False,
                copy_destination=Path(__file__).parent.parent / "Godot/addons",
                forward="/bin/addons/nobodywho",
            )
     
    
def main():
    with ThreadPoolExecutor(max_workers=len(Download_hrefs)) as ex:
        threads = [ex.submit(start_download, href) for href in Download_hrefs]

        while True:
            done = sum(current_thread.done() for current_thread in threads)
            if done == len(threads):
                break
            logging.info(f"Still downloading... {done}/{len(threads)} done")
            time.sleep(10)

        # make sure any exceptions in threads actually surface
        for current_thread in threads:
            current_thread.result()


# This is where the fun begins!
if __name__ == "__main__":
    logging.basicConfig(
        level=logging.DEBUG,
        format="[%(levelname)s]\t: %(message)s",
        handlers=[
            logging.FileHandler(
                Path(Path(__file__).parent / "Setup attempt.log").absolute()
            ),
            logging.StreamHandler(),
        ],
        force=True,
    )

    logging.info(f"Running Setup using setup")
    print("Do NOT close this script!\nIf it looks stuck it probably because download's slow")
    main()
    print("Done :)")
