import argparse
import numpy as np
import librosa
import os
import soundfile as sf
import threading
import time

NUM_THREADS = 1

if __name__ == '__main__':
    """
    audio_path  (str)  : list of paths to original audio files
    noise_path  (str)   : path to noise file
    output_path (str)   : list of paths to export the mixed audio files
    alpha       (float) : parameter to adjust noise strength, larger means more noise strength
    """
    parser = argparse.ArgumentParser(description="VIVOS Dataset noise augumentation.")
    parser.add_argument(
        "--audio_folder_path",
        help="list of paths to original audio files",
        type=str
    )
    parser.add_argument(
        "--noise_path",
        help="path to noise file",
        default='./noises/xe34.wav',
        type=str,
    )
    parser.add_argument(
        "--output_folder_path",
        help="list of paths to export the mixed audio filess",
        type=str,
    )
    parser.add_argument(
        "--alpha",
        help="parameter to adjust noise strength, larger means more noise strength",
        default=0.5,
        type=float,
    )

    args = parser.parse_args()

    audio_folder_path = args.audio_folder_path
    noise_path = args.noise_path
    output_folder_path = args.output_folder_path
    alpha = args.alpha

    # Read background file
    bg, bg_sr = librosa.load(noise_path, sr=None)

    # Resample noise
    bg = librosa.resample(bg, bg_sr, 16000)
    bg_length = bg.shape[0]

    # Create directory
    os.makedirs(output_folder_path, exist_ok=True)
    
    spk_list = os.listdir(os.path.join(audio_folder_path, 'waves'))
    spk_per_thread = int(len(spk_list) / NUM_THREADS)

    def add_noise_job(thread_index):
        if thread_index == NUM_THREADS - 1:
            thread_spk_list = spk_list[thread_index*spk_per_thread:]
        else:
            thread_spk_list = spk_list[thread_index*spk_per_thread: \
                                            thread_index*spk_per_thread+spk_per_thread]

        for spk in thread_spk_list:
            apath = os.path.join(audio_folder_path, 'waves', spk)
            opath = os.path.join(output_folder_path, 'waves', spk)
            os.makedirs(opath, exist_ok=True)

            for f in os.listdir(apath):
                audio_path = os.path.join(apath, f)
                output_path = os.path.join(opath, f)

                # Read audio file
                audio, sr = librosa.load(audio_path, sr=16000)
                audio_length = audio.shape[0]

                # Check compatibility
                if bg_length < audio_length:
                    raise Exception("Background duration cannot be smaller than audio duration!")

                # Add noise to audio
                start_ = np.random.randint(bg.shape[0] - audio_length)
                bg_slice = bg[start_ : start_ + audio_length]
                audio_with_bg = audio + bg_slice * alpha

                # Export noised audio file
                sf.write(output_path, audio_with_bg, 16000, 'PCM_16')
    
    thread_list = list()
    start_time = time.time()
    for i in range(NUM_THREADS):
        thread = threading.Thread(target=add_noise_job, args=(i,))
        thread_list.append(thread)
        thread.start()
    for thread in thread_list:
        thread.join()
    print(f"Finished, time: {time.time() - start_time}")
