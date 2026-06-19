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

def generate_industrial_footsteps(sample_rate):
    """Generates 8 heavy industrial footstep sound effects (low thud + metal clank)."""
    duration = 0.35
    num_samples = int(sample_rate * duration)
    
    for idx in range(1, 9):
        left, right = [0.0] * num_samples, [0.0] * num_samples
        
        # Randomize parameters slightly per step for variation
        thud_freq = random.uniform(45.0, 55.0)
        thud_decay = random.uniform(22.0, 28.0)
        
        clank_freqs = [
            random.uniform(700.0, 900.0),
            random.uniform(1100.0, 1300.0),
            random.uniform(1500.0, 1800.0)
        ]
        clank_decay = random.uniform(35.0, 45.0)
        
        for i in range(num_samples):
            t = i / sample_rate
            
            # Low thud (heavy boot impact)
            thud = math.sin(2 * math.pi * thud_freq * t) * math.exp(-t * thud_decay) * 0.75
            
            # Metal clank (dissonant high-pitch ring)
            clank = 0.0
            for f in clank_freqs:
                clank += math.sin(2 * math.pi * f * t) * 0.12
            clank *= math.exp(-t * clank_decay)
            
            # Floor grit/friction (noise burst)
            noise = random.uniform(-1.0, 1.0) * math.exp(-t * 50.0) * 0.15
            
            val = thud + clank + noise
            val = max(-1.0, min(1.0, val))
            
            # 12-bit crush
            val = round(val * 2048.0) / 2048.0
            
            left[i] = val
            right[i] = val
            
        wav_path = f"sfx/temp_step_ind_{idx}.wav"
        mp3_path = f"sfx/step_industrial_{idx}.mp3"
        save_wav(wav_path, left, right, sample_rate)
        convert_to_mp3(wav_path, mp3_path)

def generate_industrial_ambience(sample_rate):
    """Generates a 30-second seamless looping industrial drone + machinery clanks."""
    duration = 30.0
    num_samples = int(sample_rate * duration)
    left, right = [0.0] * num_samples, [0.0] * num_samples
    
    # 1. Base drone (multiple deep sub-bass frequencies)
    drone_freqs = [35.0, 53.0, 70.0, 110.0]
    
    # 2. Distant machinery clanks: pre-determine hit times and parameters
    hits = []
    num_hits = 10
    for _ in range(num_hits):
        hit_t = random.uniform(1.0, duration - 3.0)
        hit_freqs = [random.uniform(400.0, 600.0), random.uniform(900.0, 1200.0)]
        hit_vol = random.uniform(0.08, 0.18)
        hits.append((hit_t, hit_freqs, hit_vol))
        
    for i in range(num_samples):
        t = i / sample_rate
        
        # Deep drone with slow LFO volume modulation
        drone_val = 0.0
        for idx, f in enumerate(drone_freqs):
            lfo = 0.6 + 0.4 * math.sin(2 * math.pi * (0.05 + idx * 0.03) * t)
            drone_val += math.sin(2 * math.pi * f * t) * 0.15 * lfo
            
        # Heavy low rumble hum
        hum = math.sin(2 * math.pi * 60.0 * t) * 0.04 * (0.8 + 0.2 * math.sin(2 * math.pi * 0.2 * t))
        
        # Distant clanks
        clanks_val = 0.0
        for hit_t, hit_freqs, hit_vol in hits:
            if t >= hit_t:
                dt = t - hit_t
                env = math.exp(-dt * 6.0) # rapidly decaying clank
                clank_sig = 0.0
                for hf in hit_freqs:
                    clank_sig += math.sin(2 * math.pi * hf * dt) * 0.5
                clanks_val += clank_sig * env * hit_vol
                
        # Background machinery hiss (low-level white noise with high-pass)
        hiss = random.uniform(-1.0, 1.0) * 0.012
        
        val = drone_val + hum + clanks_val + hiss
        val = max(-1.0, min(1.0, val))
        
        # 12-bit crush
        val = round(val * 2048.0) / 2048.0
        
        left[i] = val
        right[i] = val
        
    # Crossfade endpoints (2.0 seconds) for seamless looping
    fade_len = int(2.0 * sample_rate)
    for i in range(fade_len):
        fade_out = 1.0 - (i / fade_len)
        fade_in = i / fade_len
        end_idx = num_samples - fade_len + i
        beg_idx = i
        
        l_blend = (left[end_idx] * fade_out) + (left[beg_idx] * fade_in)
        r_blend = (right[end_idx] * fade_out) + (right[beg_idx] * fade_in)
        
        left[beg_idx] = l_blend
        right[beg_idx] = r_blend
        
    final_samples = num_samples - fade_len
    left = left[:final_samples]
    right = right[:final_samples]
    
    save_wav("sfx/temp_amb_ind.wav", left, right, sample_rate)
    convert_to_mp3("sfx/temp_amb_ind.wav", "sfx/ambience_industrial.mp3")

if __name__ == "__main__":
    sample_rate = 22050
    print("Generating Industrial footsteps...")
    generate_industrial_footsteps(sample_rate)
    print("Generating Industrial ambience...")
    generate_industrial_ambience(sample_rate)
    print("Industrial audio assets generated successfully!")
