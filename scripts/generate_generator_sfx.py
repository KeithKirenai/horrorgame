import math
import struct
import wave
import os
import subprocess
import random

def save_wav(filename, left, right, sample_rate):
    """Saves a stereo floating-point audio signal to a 16-bit WAV file."""
    with wave.open(filename, "wb") as f:
        f.setnchannels(2)
        f.setsampwidth(2)
        f.setframerate(sample_rate)
        for i in range(len(left)):
            l_val = int(max(-1.0, min(1.0, left[i])) * 32767)
            r_val = int(max(-1.0, min(1.0, right[i])) * 32767)
            f.writeframesraw(struct.pack("<hh", l_val, r_val))

def convert_to_mp3(wav_path, mp3_path):
    """Converts a WAV file to MP3 using ffmpeg, then deletes the WAV."""
    cmd = ["ffmpeg", "-y", "-i", wav_path, "-codec:a", "libmp3lame", "-b:a", "96k", mp3_path]
    try:
        subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        print(f"Generated: {mp3_path}")
    except subprocess.CalledProcessError as e:
        print(f"Error converting {wav_path} to MP3: {e.stderr.decode('utf-8', errors='ignore')}")
    finally:
        if os.path.exists(wav_path):
            os.remove(wav_path)

def generate_crank(sample_rate):
    """Synthesizes a single heavy diesel engine compression starter crank."""
    duration = 0.25
    num_samples = int(sample_rate * duration)
    left, right = [0.0] * num_samples, [0.0] * num_samples
    
    for i in range(num_samples):
        t = i / sample_rate
        # Transient starter motor click (rapid decay pitch sweep)
        transient_freq = 2500.0 * math.exp(-t * 300.0) + 100.0
        click = math.sin(2 * math.pi * transient_freq * t) * math.exp(-t * 200.0) * 0.4
        
        # Heavy piston compression pop (low frequency saw/triangle)
        bass_freq = 45.0
        env = math.exp(-t * 15.0)
        # Blend of fundamental & harmonics for metallic grunt
        piston = 0.0
        for h in range(1, 4):
            piston += math.sin(2 * math.pi * bass_freq * h * t) * (1.0 / h)
        piston = piston * env * 0.6
        
        # Add starter gear grind noise (high pass filtered white noise)
        noise = random.uniform(-1.0, 1.0) * 0.06 * math.exp(-t * 25.0)
        
        val = click + piston + noise
        # 12-bit quantization for PS1 texture
        val = round(val * 2048.0) / 2048.0
        
        left[i] = val
        right[i] = val
        
    save_wav("sfx/temp_crank.wav", left, right, sample_rate)
    convert_to_mp3("sfx/temp_crank.wav", "sfx/generator_crank.mp3")

def generate_hum(sample_rate):
    """Synthesizes a looping heavy diesel generator engine rumble."""
    duration = 2.0  # Perfect looping length
    num_samples = int(sample_rate * duration)
    left, right = [0.0] * num_samples, [0.0] * num_samples
    
    base_freq = 50.0  # 50 Hz idle hum
    firing_rate = 25.0 # Combustion stroke frequency (four-stroke engine)
    
    for i in range(num_samples):
        t = i / sample_rate
        
        # Low frequency diesel cylinder combustion explosions
        engine_val = 0.0
        # Add rich harmonics representing mechanical clatter and exhaust note
        for h in range(1, 8):
            amp = 1.0 / h
            # Detune slightly for realistic chorus/depth
            engine_val += math.sin(2 * math.pi * base_freq * h * t) * amp
            
        # Amplitude modulate at the firing rate to simulate cylinder strokes
        combustion_env = 0.6 + 0.4 * math.sin(2 * math.pi * firing_rate * t)
        engine_val *= combustion_env * 0.45
        
        # Add low-frequency sub-rumble
        sub_rumble = math.sin(2 * math.pi * 25.0 * t) * 0.15
        
        # Mechanical gear rattle (high pass filtered noise modulated by combustion)
        rattle = random.uniform(-1.0, 1.0) * 0.04 * (0.3 + 0.7 * math.sin(2 * math.pi * firing_rate * t))
        
        # Mix everything
        val = engine_val + sub_rumble + rattle
        val = max(-1.0, min(1.0, val))
        
        # Apply 12-bit bitcrushing
        val = round(val * 2048.0) / 2048.0
        
        # Wide stereo image (phase shift slightly between left and right)
        left[i] = val
        # 1.5ms delay on right channel for Haas stereo effect
        r_idx = max(0, i - int(sample_rate * 0.0015))
        right[i] = left[r_idx]
        
    save_wav("sfx/temp_hum.wav", left, right, sample_rate)
    convert_to_mp3("sfx/temp_hum.wav", "sfx/generator_hum.mp3")

def generate_start(sample_rate):
    """Synthesizes a diesel engine startup sequence catching, revving up, and chiming when online."""
    duration = 4.0
    num_samples = int(sample_rate * duration)
    left, right = [0.0] * num_samples, [0.0] * num_samples
    
    # 1. Startup phase (t=0.0 to t=1.2s): Accelerating engine cranking pops
    # Crank timings (acceleration curve)
    crank_times = [0.0, 0.45, 0.78, 1.02, 1.2]
    
    # Write the cranking pulses manually into the stream
    for c_t in crank_times:
        start_idx = int(c_t * sample_rate)
        end_idx = min(start_idx + int(0.25 * sample_rate), num_samples)
        for i in range(start_idx, end_idx):
            bt = (i - start_idx) / sample_rate
            # Piston sound
            piston = math.sin(2 * math.pi * 40.0 * bt) * math.exp(-bt * 15.0) * 0.5
            # Gear noise
            noise = random.uniform(-1.0, 1.0) * 0.08 * math.exp(-bt * 30.0)
            val = piston + noise
            left[i] += val
            right[i] += val
            
    # 2. Catch & Rev Up (t=1.3 to t=2.6s): Sputtering and ramping up to speed
    catch_start = 1.3
    for i in range(int(catch_start * sample_rate), num_samples):
        t = i / sample_rate
        bt = t - catch_start
        
        # Ramping up frequencies
        freq_scale = min(1.0, bt / 1.2) # reach full frequency in 1.2s
        curr_freq = 25.0 + 25.0 * freq_scale # ramp from 25Hz to 50Hz
        curr_firing = curr_freq / 2.0
        
        # Engine hum composition
        engine_val = 0.0
        for h in range(1, 8):
            engine_val += math.sin(2 * math.pi * curr_freq * h * bt) * (1.0 / h)
            
        # Sputter envelope (uneven firing during catch phase)
        sputter = 1.0
        if bt < 0.6:
            # Dropouts/misfires represented by low LFO amplitude gaps
            sputter = 0.4 + 0.6 * math.sin(2 * math.pi * 8.0 * bt)
            
        env = min(1.0, bt / 0.8) * sputter * 0.4
        rattle = random.uniform(-1.0, 1.0) * 0.04 * env
        
        val = (engine_val * env) + rattle
        left[i] += val
        right[i] += val
        
    # 3. Startup Completed Chime (t=2.7 to t=3.3s): Clear warning beep signal
    chime_start = 2.7
    chime_dur = 0.4
    chime_freq = 1960.0 # High pitched distinct bell-chime (B6)
    
    start_chime_idx = int(chime_start * sample_rate)
    end_chime_idx = min(start_chime_idx + int(chime_dur * sample_rate), num_samples)
    
    for i in range(start_chime_idx, end_chime_idx):
        t = i / sample_rate
        bt = t - chime_start
        
        # Bell/warning chime with exponential decay envelope
        chime_env = math.exp(-bt * 5.0)
        chime_val = math.sin(2 * math.pi * chime_freq * bt) * chime_env * 0.5
        
        # Blend into the audio
        left[i] += chime_val
        right[i] += chime_val
        
    # Apply global soft limiting, bitcrushing, and panning
    for i in range(num_samples):
        val_l = max(-1.0, min(1.0, left[i]))
        val_r = max(-1.0, min(1.0, right[i]))
        
        # 12-bit crush
        left[i] = round(val_l * 2048.0) / 2048.0
        right[i] = round(val_r * 2048.0) / 2048.0
        
    save_wav("sfx/temp_start.wav", left, right, sample_rate)
    convert_to_mp3("sfx/temp_start.wav", "sfx/generator_start.mp3")

def generate_off(sample_rate):
    """Synthesizes a diesel generator engine shutting down, slowing down to a stop."""
    duration = 2.0
    num_samples = int(sample_rate * duration)
    left, right = [0.0] * num_samples, [0.0] * num_samples
    
    for i in range(num_samples):
        t = i / sample_rate
        # Slowing down factor
        slow_factor = max(0.0, 1.0 - t / 1.5)
        curr_freq = 50.0 * slow_factor
        curr_firing = curr_freq / 2.0
        
        # Engine decay envelope
        env = slow_factor * 0.4
        
        engine_val = 0.0
        if curr_freq > 2.0:
            for h in range(1, 6):
                engine_val += math.sin(2 * math.pi * curr_freq * h * t) * (1.0 / h)
            
            # Amplitude modulation for cylinder piston strokes
            engine_val *= (0.6 + 0.4 * math.sin(2 * math.pi * curr_firing * t))
            
        rattle = random.uniform(-1.0, 1.0) * 0.03 * env
        
        val = (engine_val * env) + rattle
        val = round(val * 2048.0) / 2048.0
        
        left[i] = val
        right[i] = val
        
    save_wav("sfx/temp_off.wav", left, right, sample_rate)
    convert_to_mp3("sfx/temp_off.wav", "sfx/generator_off.mp3")

if __name__ == "__main__":
    sample_rate = 22050
    print("Generating generator_crank.mp3...")
    generate_crank(sample_rate)
    
    print("Generating generator_hum.mp3...")
    generate_hum(sample_rate)
    
    print("Generating generator_start.mp3...")
    generate_start(sample_rate)
    
    print("Generating generator_off.mp3...")
    generate_off(sample_rate)
    
    print("All generator SFX files generated successfully!")
