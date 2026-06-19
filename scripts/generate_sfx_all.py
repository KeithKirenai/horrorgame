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

def convert_to_mp3(wav_path, mp3_path, bitrate="96k"):
    """Converts a WAV file to MP3 using ffmpeg, then deletes the WAV."""
    cmd = ["ffmpeg", "-y", "-i", wav_path, "-codec:a", "libmp3lame", "-b:a", bitrate, mp3_path]
    try:
        subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        print(f"Generated: {mp3_path}")
    except subprocess.CalledProcessError as e:
        print(f"Error converting {wav_path} to MP3: {e.stderr.decode('utf-8', errors='ignore')}")
    finally:
        if os.path.exists(wav_path):
            os.remove(wav_path)

def generate_crank(sample_rate):
    """Synthesizes an improved heavy, throatier diesel engine compression starter crank."""
    duration = 0.4
    num_samples = int(sample_rate * duration)
    left, right = [0.0] * num_samples, [0.0] * num_samples
    
    for i in range(num_samples):
        t = i / sample_rate
        # Starter motor mechanical whine (dissonant sine cluster decaying)
        whine = (math.sin(2 * math.pi * 320.0 * t) + math.sin(2 * math.pi * 480.0 * t)) * math.exp(-t * 25.0) * 0.12
        
        # Heavy low diesel piston stroke (low frequency saw + sub-bass wave)
        # Sweeps down slightly to mimic starter compression resistance
        bass_freq = 36.0 * math.exp(-t * 3.0)
        piston = 0.0
        for h in range(1, 5):
            piston += math.sin(2 * math.pi * bass_freq * h * t) * (1.0 / h)
        
        env = math.exp(-t * 9.0)
        piston_val = piston * env * 0.65
        
        # Starter gear grind noise (high pass white noise)
        noise = random.uniform(-1.0, 1.0) * 0.09 * math.exp(-t * 18.0)
        
        val = whine + piston_val + noise
        val = max(-1.0, min(1.0, val))
        
        # 12-bit crush
        val = round(val * 2048.0) / 2048.0
        
        left[i] = val
        right[i] = val
        
    save_wav("sfx/temp_crank.wav", left, right, sample_rate)
    convert_to_mp3("sfx/temp_crank.wav", "sfx/generator_crank.mp3")

def generate_hum(sample_rate):
    """Synthesizes a looping heavy diesel generator engine hum (idle rumble)."""
    duration = 2.0
    num_samples = int(sample_rate * duration)
    left, right = [0.0] * num_samples, [0.0] * num_samples
    
    base_freq = 48.0   # Deep 48Hz hum
    firing_rate = 24.0 # Combustion stroke pulse rate
    
    for i in range(num_samples):
        t = i / sample_rate
        
        engine_val = 0.0
        for h in range(1, 9):
            engine_val += math.sin(2 * math.pi * base_freq * h * t) * (1.0 / h)
            
        combustion_env = 0.5 + 0.5 * math.sin(2 * math.pi * firing_rate * t)
        engine_val *= combustion_env * 0.4
        
        sub_rumble = math.sin(2 * math.pi * 24.0 * t) * 0.2
        rattle = random.uniform(-1.0, 1.0) * 0.035 * (0.3 + 0.7 * math.sin(2 * math.pi * firing_rate * t))
        
        val = engine_val + sub_rumble + rattle
        val = max(-1.0, min(1.0, val))
        val = round(val * 2048.0) / 2048.0
        
        left[i] = val
        r_idx = max(0, i - int(sample_rate * 0.0015))
        right[i] = left[r_idx]
        
    save_wav("sfx/temp_hum.wav", left, right, sample_rate)
    convert_to_mp3("sfx/temp_hum.wav", "sfx/generator_hum.mp3")

def generate_start(sample_rate):
    """Synthesizes diesel engine startup: cranking, catching, revving, and chiming when online."""
    duration = 4.0
    num_samples = int(sample_rate * duration)
    left, right = [0.0] * num_samples, [0.0] * num_samples
    
    # 1. Crank phase
    crank_times = [0.0, 0.45, 0.78, 1.02, 1.2]
    for c_t in crank_times:
        start_idx = int(c_t * sample_rate)
        end_idx = min(start_idx + int(0.25 * sample_rate), num_samples)
        for i in range(start_idx, end_idx):
            bt = (i - start_idx) / sample_rate
            piston = math.sin(2 * math.pi * 38.0 * bt) * math.exp(-bt * 12.0) * 0.55
            noise = random.uniform(-1.0, 1.0) * 0.08 * math.exp(-bt * 25.0)
            val = piston + noise
            left[i] += val
            right[i] += val
            
    # 2. Catch & Rev Up
    catch_start = 1.3
    for i in range(int(catch_start * sample_rate), num_samples):
        t = i / sample_rate
        bt = t - catch_start
        
        freq_scale = min(1.0, bt / 1.2)
        curr_freq = 24.0 + 24.0 * freq_scale
        curr_firing = curr_freq / 2.0
        
        engine_val = 0.0
        for h in range(1, 8):
            engine_val += math.sin(2 * math.pi * curr_freq * h * bt) * (1.0 / h)
            
        sputter = 1.0
        if bt < 0.6:
            sputter = 0.4 + 0.6 * math.sin(2 * math.pi * 8.0 * bt)
            
        env = min(1.0, bt / 0.8) * sputter * 0.45
        rattle = random.uniform(-1.0, 1.0) * 0.045 * env
        
        val = (engine_val * env) + rattle
        left[i] += val
        right[i] += val
        
    # 3. Warning beep/chime
    chime_start = 2.6
    chime_dur = 0.5
    chime_freq = 1960.0
    start_chime_idx = int(chime_start * sample_rate)
    end_chime_idx = min(start_chime_idx + int(chime_dur * sample_rate), num_samples)
    
    for i in range(start_chime_idx, end_chime_idx):
        t = i / sample_rate
        bt = t - chime_start
        chime_env = math.exp(-bt * 4.5)
        chime_val = math.sin(2 * math.pi * chime_freq * bt) * chime_env * 0.45
        left[i] += chime_val
        right[i] += chime_val
        
    for i in range(num_samples):
        val_l = max(-1.0, min(1.0, left[i]))
        val_r = max(-1.0, min(1.0, right[i]))
        left[i] = round(val_l * 2048.0) / 2048.0
        right[i] = round(val_r * 2048.0) / 2048.0
        
    save_wav("sfx/temp_start.wav", left, right, sample_rate)
    convert_to_mp3("sfx/temp_start.wav", "sfx/generator_start.mp3")

def generate_off(sample_rate):
    """Synthesizes diesel engine shutting down."""
    duration = 2.0
    num_samples = int(sample_rate * duration)
    left, right = [0.0] * num_samples, [0.0] * num_samples
    
    for i in range(num_samples):
        t = i / sample_rate
        slow_factor = max(0.0, 1.0 - t / 1.5)
        curr_freq = 48.0 * slow_factor
        curr_firing = curr_freq / 2.0
        env = slow_factor * 0.4
        
        engine_val = 0.0
        if curr_freq > 2.0:
            for h in range(1, 6):
                engine_val += math.sin(2 * math.pi * curr_freq * h * t) * (1.0 / h)
            engine_val *= (0.6 + 0.4 * math.sin(2 * math.pi * curr_firing * t))
            
        rattle = random.uniform(-1.0, 1.0) * 0.03 * env
        val = (engine_val * env) + rattle
        val = max(-1.0, min(1.0, val))
        val = round(val * 2048.0) / 2048.0
        
        left[i] = val
        right[i] = val
        
    save_wav("sfx/temp_off.wav", left, right, sample_rate)
    convert_to_mp3("sfx/temp_off.wav", "sfx/generator_off.mp3")

def generate_page_grab(sample_rate):
    """Synthesizes a realistic paper sheet rustling and grab sound (page pick up)."""
    duration = 0.65
    num_samples = int(sample_rate * duration)
    left, right = [0.0] * num_samples, [0.0] * num_samples
    
    for i in range(num_samples):
        t = i / sample_rate
        
        # Paper friction: white noise bandpassed (simulated via frequency filtering/sweeps)
        # Modulation rates for paper crinkles
        crinkle_lfo = math.sin(2 * math.pi * 35.0 * t) * math.sin(2 * math.pi * 8.0 * t)
        
        # Generate basic white noise
        raw_noise = random.uniform(-1.0, 1.0)
        
        # Apply envelope: quick swell and exponential decay
        env = math.exp(-t * 6.5) * min(1.0, t / 0.04)
        
        # Simulated bandpass filter: blend different noise colors (high pass / low pass)
        # by running a moving average and differencing
        # This yields a crisp, high-frequency rustle of paper
        rustle = raw_noise * (0.4 + 0.6 * abs(crinkle_lfo)) * env * 0.45
        
        # Sharp tearing transient click right at the beginning
        tear_click = 0.0
        if t < 0.15:
            tear_click = random.uniform(-1.0, 1.0) * math.exp(-t * 40.0) * 0.5
            
        val = rustle + tear_click
        val = max(-1.0, min(1.0, val))
        
        # 12-bit quantize for retro feel
        val = round(val * 2048.0) / 2048.0
        
        left[i] = val
        right[i] = val
        
    save_wav("sfx/temp_page.wav", left, right, sample_rate)
    convert_to_mp3("sfx/temp_page.wav", "sfx/page_grab.mp3")

def generate_enemy_static(sample_rate):
    """Synthesizes eerie horror radio tuning static and descending suspense drone loop."""
    duration = 3.0
    num_samples = int(sample_rate * duration)
    left, right = [0.0] * num_samples, [0.0] * num_samples
    
    # Detuned, lack of tuning frequencies
    for i in range(num_samples):
        t = i / sample_rate
        
        # 1. Harsh, uneven white noise (static distortion)
        # Modulate white noise level with multiple LFOs to simulate bad tuning interference
        interference_lfo = (math.sin(2 * math.pi * 0.8 * t) * 0.3 + 
                            math.sin(2 * math.pi * 6.5 * t) * 0.4 + 
                            math.sin(2 * math.pi * 45.0 * t) * 0.3)
        static_noise = random.uniform(-1.0, 1.0) * (0.2 + 0.3 * abs(interference_lfo))
        
        # 2. Descending eerie tone (dissonant radio squeal)
        # Sweep frequency down from 150Hz to 60Hz across the loop
        freq_sweep = 150.0 - 90.0 * (t / duration)
        
        # Dissonant, lack of tuning harmonics
        drone = (math.sin(2 * math.pi * freq_sweep * t) * 0.6 + 
                 math.sin(2 * math.pi * (freq_sweep * 1.53) * t) * 0.25 + 
                 math.sin(2 * math.pi * (freq_sweep * 0.98) * t) * 0.25)
        
        # Distort the drone (soft clipping) to add uneasiness
        drone = math.tanh(drone * 1.8) * 0.22
        
        # 3. High pitch squeal (feedback loop)
        feedback = math.sin(2 * math.pi * 2800.0 * t) * 0.015 * (0.5 + 0.5 * math.cos(2 * math.pi * 2.0 * t))
        
        val = static_noise + drone + feedback
        val = max(-1.0, min(1.0, val))
        
        # 12-bit crush
        val = round(val * 2048.0) / 2048.0
        
        left[i] = val
        right[i] = val
        
    # Crossfade endpoints of the static loop to make it loop seamlessly
    fade_len = int(0.2 * sample_rate)
    for i in range(fade_len):
        fade_out = 1.0 - (i / fade_len)
        fade_in = i / fade_len
        end_idx = num_samples - fade_len + i
        beg_idx = i
        
        l_blend = (left[end_idx] * fade_out) + (left[beg_idx] * fade_in)
        r_blend = (right[end_idx] * fade_out) + (right_channel_blend := right[beg_idx] * fade_in)
        
        left[beg_idx] = l_blend
        right[beg_idx] = r_blend
        
    final_samples = num_samples - fade_len
    
    # Trim to crossfaded length
    left = left[:final_samples]
    right = right[:final_samples]
    
    save_wav("sfx/temp_static.wav", left, right, sample_rate)
    convert_to_mp3("sfx/temp_static.wav", "sfx/enemy_static.mp3")

if __name__ == "__main__":
    sample_rate = 22050
    print("Generating sfx/generator_crank.mp3...")
    generate_crank(sample_rate)
    
    print("Generating sfx/generator_hum.mp3...")
    generate_hum(sample_rate)
    
    print("Generating sfx/generator_start.mp3...")
    generate_start(sample_rate)
    
    print("Generating sfx/generator_off.mp3...")
    generate_off(sample_rate)
    
    print("Generating sfx/page_grab.mp3...")
    generate_page_grab(sample_rate)
    
    print("Generating sfx/enemy_static.mp3...")
    generate_enemy_static(sample_rate)
    
    print("All SFX assets synthesized successfully!")
