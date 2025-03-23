import boto3
import re
import os
import subprocess
from pydub import AudioSegment

# Initialize Polly client
polly = boto3.client("polly", region_name="us-east-1")

def sanitize_filename(text):
    text = text.lower().replace(" ", "_")
    text = re.sub(r"[^\w_]", "", text)
    return f"{text}.mp3"

# Load prompts
input_file = "prompts.txt"
prompts = {}

with open(input_file, "r", encoding="utf-8") as file:
    for line in file:
        line = line.strip()
        if ":" in line:
            file_name, prompt = line.split(":", 1)
            file_name = sanitize_filename(file_name.strip())
            prompt = prompt.strip()
            prompts[file_name] = prompt

# Generate MP3 files with Polly
for file_name, phrase in prompts.items():
    print(f"Generating: {file_name}")

    response = polly.synthesize_speech(
        Text=phrase,
        OutputFormat="mp3",
        VoiceId="Amy",
        Engine="neural"
    )

    with open(file_name, "wb") as file:
        file.write(response["AudioStream"].read())

# Convert MP3 to raw A-law .au using sox
for mp3_file in prompts.keys():
    base_name = mp3_file.replace(".mp3", "")
    au_file = f"{base_name}.au"

    print(f"Converting {mp3_file} to raw A-law .au: {au_file}")

    # Boost volume first
    audio = AudioSegment.from_mp3(mp3_file)
    audio += 5  # Increase by 5 dB
    boosted_mp3 = f"{base_name}_boosted.mp3"
    audio.export(boosted_mp3, format="mp3")

    # Use sox to convert boosted MP3 to .au with A-law encoding
    subprocess.run([
        "sox", boosted_mp3,
        "-r", "8000",
        "-c", "1",
        "-e", "a-law",
        au_file
    ], check=True)

    # Cleanup
    os.remove(mp3_file)
    os.remove(boosted_mp3)
    print(f"Deleted {mp3_file} and {boosted_mp3}")

print("All prompts converted to raw A-law .au files successfully.")

