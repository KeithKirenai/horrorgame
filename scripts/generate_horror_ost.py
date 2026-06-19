import math
import struct
import wave
import random
import os
import subprocess
import json

def encode_vlq(value):
    """Encodes an integer into a MIDI Variable Length Quantity (VLQ) bytearray."""
    bytes_out = bytearray()
    value = int(round(value))
    if value < 0:
        value = 0
    while True:
        byte = value & 0x7F
        value >>= 7
        if value > 0:
            byte |= 0x80
        bytes_out.insert(0, byte)
        if value == 0:
            break
    return bytes_out

def hz_to_midi(hz):
    """Converts a frequency in Hz to the nearest MIDI note number."""
    return int(round(69 + 12 * math.log2(hz / 440.0)))

def save_midi(midi_filename, tempo_bpm, drone_notes, melody_notes, swell_notes, percussion_notes):
    """Writes a standard Multi-track Type 1 MIDI file containing the composition structure."""
    ticks_per_quarter = 480
    tempo_us = int(60_000_000 / tempo_bpm)
    
    # Track 0: Tempo and Drone track
    track0 = bytearray()
    track0.extend(b'\x00\xFF\x58\x04\x04\x02\x18\x08')
    track0.extend(b'\x00\xFF\x51\x03' + struct.pack('>I', tempo_us)[1:])
    track0.extend(b'\x00\xC0\x5C') # Program 93
    
    drone_events = []
    for d in drone_notes:
        drone_events.append({"time": d["time"], "pitch": d["pitch"], "type": "on", "vel": d["vel"]})
        drone_events.append({"time": d["time"] + d["duration"], "pitch": d["pitch"], "type": "off", "vel": 0})
    drone_events.sort(key=lambda x: (x["time"], 0 if x["type"] == "off" else 1))
    
    last_tick = 0
    for ev in drone_events:
        curr_tick = int(ev["time"] * ticks_per_quarter)
        delta = curr_tick - last_tick
        track0.extend(encode_vlq(delta))
        if ev["type"] == "on":
            track0.extend(struct.pack('BBB', 0x90, ev["pitch"], ev["vel"]))
        else:
            track0.extend(struct.pack('BBB', 0x80, ev["pitch"], 0))
        last_tick = curr_tick
    track0.extend(b'\x00\xFF\x2F\x00')
    
    # Track 1: Melody (Bells) track
    track1 = bytearray()
    track1.extend(b'\x00\xFF\x03\x05Bells')
    track1.extend(b'\x00\xC1\x09') # Program 10
    
    melody_events = []
    for m in melody_notes:
        melody_events.append({"time": m["time"], "pitch": m["pitch"], "type": "on", "vel": m["vel"]})
        melody_events.append({"time": m["time"] + m["duration"], "pitch": m["pitch"], "type": "off", "vel": 0})
    melody_events.sort(key=lambda x: (x["time"], 0 if x["type"] == "off" else 1))
    
    last_tick = 0
    for ev in melody_events:
        curr_tick = int(ev["time"] * ticks_per_quarter)
        delta = curr_tick - last_tick
        track1.extend(encode_vlq(delta))
        if ev["type"] == "on":
            track1.extend(struct.pack('BBB', 0x91, ev["pitch"], ev["vel"]))
        else:
            track1.extend(struct.pack('BBB', 0x81, ev["pitch"], 0))
        last_tick = curr_tick
    track1.extend(b'\x00\xFF\x2F\x00')
    
    # Track 2: Swells track
    track2 = bytearray()
    track2.extend(b'\x00\xFF\x03\x06Swells')
    track2.extend(b'\x00\xC2\x32') # Program 51
    
    swell_events = []
    for s in swell_notes:
        swell_events.append({"time": s["time"], "pitch": s["pitch"], "type": "on", "vel": s["vel"]})
        swell_events.append({"time": s["time"] + s["duration"], "pitch": s["pitch"], "type": "off", "vel": 0})
    swell_events.sort(key=lambda x: (x["time"], 0 if x["type"] == "off" else 1))
    
    last_tick = 0
    for ev in swell_events:
        curr_tick = int(ev["time"] * ticks_per_quarter)
        delta = curr_tick - last_tick
        track2.extend(encode_vlq(delta))
        if ev["type"] == "on":
            track2.extend(struct.pack('BBB', 0x92, ev["pitch"], ev["vel"]))
        else:
            track2.extend(struct.pack('BBB', 0x82, ev["pitch"], 0))
        last_tick = curr_tick
    track2.extend(b'\x00\xFF\x2F\x00')

    # Track 3: Percussion track (Channel 9 for General MIDI percussion)
    track3 = bytearray()
    track3.extend(b'\x00\xFF\x03\x0AHeartbeat')
    
    perc_events = []
    for p in percussion_notes:
        perc_events.append({"time": p["time"], "pitch": p["pitch"], "type": "on", "vel": p["vel"]})
        perc_events.append({"time": p["time"] + p["duration"], "pitch": p["pitch"], "type": "off", "vel": 0})
    perc_events.sort(key=lambda x: (x["time"], 0 if x["type"] == "off" else 1))
    
    last_tick = 0
    for ev in perc_events:
        curr_tick = int(ev["time"] * ticks_per_quarter)
        delta = curr_tick - last_tick
        track3.extend(encode_vlq(delta))
        if ev["type"] == "on":
            track3.extend(struct.pack('BBB', 0x99, ev["pitch"], ev["vel"])) # Channel 10 (0x99)
        else:
            track3.extend(struct.pack('BBB', 0x89, ev["pitch"], 0))
        last_tick = curr_tick
    track3.extend(b'\x00\xFF\x2F\x00')
    
    num_tracks = 4
    with open(midi_filename, "wb") as f:
        f.write(b'MThd' + struct.pack('>IHHH', 6, 1, num_tracks, ticks_per_quarter))
        f.write(b'MTrk' + struct.pack('>I', len(track0)) + track0)
        f.write(b'MTrk' + struct.pack('>I', len(track1)) + track1)
        f.write(b'MTrk' + struct.pack('>I', len(track2)) + track2)
        f.write(b'MTrk' + struct.pack('>I', len(track3)) + track3)
        
    print(f"MIDI structure preserved in {midi_filename}")

def generate_horror_ost():
    sample_rate = 22050
    duration = 30.0
    num_samples = int(sample_rate * duration)
    tempo_bpm = 48.0     # Even slower pacing for extreme dread
    beats_per_second = tempo_bpm / 60.0
    
    left_channel = [0.0] * num_samples
    right_channel = [0.0] * num_samples
    
    drone_notes_meta = []
    melody_notes_meta = []
    swell_notes_meta = []
    percussion_notes_meta = []
    
    # ----------------------------------------------------
    # TRACK 1: Drone (Tritones shifting every 15s)
    # ----------------------------------------------------
    print("Generating shifting drone...")
    # 0-15s: E1 (41.2 Hz) + A#1 (58.27 Hz)
    # 15-30s: F1 (43.65 Hz) + B1 (61.74 Hz)
    drone_notes_meta.append({"time": 0.0, "pitch": 28, "duration": 15.0 * beats_per_second, "vel": 80}) # E1
    drone_notes_meta.append({"time": 0.0, "pitch": 34, "duration": 15.0 * beats_per_second, "vel": 70}) # A#1
    drone_notes_meta.append({"time": 15.0 * beats_per_second, "pitch": 29, "duration": 15.0 * beats_per_second, "vel": 80}) # F1
    drone_notes_meta.append({"time": 15.0 * beats_per_second, "pitch": 35, "duration": 15.0 * beats_per_second, "vel": 70}) # B1
    
    for i in range(num_samples):
        t = i / sample_rate
        lfo1 = math.sin(2 * math.pi * 0.08 * t)
        lfo2 = math.cos(2 * math.pi * 0.05 * t)
        
        if t < 15.0:
            f1, f2 = 41.20, 58.27
        else:
            f1, f2 = 43.65, 61.74
            
        wave1 = math.sin(2 * math.pi * (f1 + lfo1 * 0.2) * t)
        wave2 = math.sin(2 * math.pi * (f2 + lfo2 * 0.3) * t)
        
        bass_mix = (wave1 * 0.65 + wave2 * 0.35)
        
        # Add 60Hz hum and filtered brown/white noise for tape rattle
        hum = math.sin(2 * math.pi * 60.0 * t) * 0.04
        noise = random.uniform(-1.0, 1.0) * 0.025
        
        drone_sample = (bass_mix * 0.35) + hum + noise
        
        pan = 0.5 + 0.2 * math.sin(2 * math.pi * 0.04 * t)
        left_channel[i] += drone_sample * (1.0 - pan)
        right_channel[i] += drone_sample * pan

    # ----------------------------------------------------
    # TRACK 2: Improved Structured Phrygian Melody (Bells)
    # ----------------------------------------------------
    print("Generating structured Phrygian melody...")
    # Motif: E6 -> F6 -> E6 -> B5 -> C6 -> G#5 -> A5 -> E5 -> D#5 (dissonant ending)
    melody_events = [
        # (Start time in seconds, MIDI pitch, freq in Hz, volume)
        (1.5, 88, 1318.51, 0.35),  # E6
        (3.5, 89, 1396.91, 0.32),  # F6
        (5.5, 88, 1318.51, 0.30),  # E6
        (7.5, 83, 987.77,  0.28),  # B5
        (9.5, 84, 1046.50, 0.28),  # C6
        (12.0, 80, 830.61,  0.30),  # G#5
        (14.0, 81, 880.00,  0.30),  # A5
        (16.5, 76, 659.25,  0.28),  # E5
        (19.0, 75, 622.25,  0.35),  # D#5 (jarring minor second transition)
        (22.0, 88, 1318.51, 0.38),  # E6 high chime
        (24.5, 94, 1864.66, 0.40),  # A#6 (screaming tritone chime)
    ]
    
    for start_t, midi_p, hz, vol in melody_events:
        bell_dur = 3.5
        melody_notes_meta.append({
            "time": start_t * beats_per_second,
            "pitch": midi_p,
            "duration": bell_dur * beats_per_second,
            "vel": int(vol * 320)
        })
        
        start_idx = int(start_t * sample_rate)
        end_idx = min(start_idx + int(bell_dur * sample_rate), num_samples)
        
        harmonics = [1.0, 2.0, 2.76, 3.2, 4.15, 5.38]
        amps = [1.0, 0.45, 0.3, 0.2, 0.12, 0.08]
        decays = [1.2, 1.5, 2.0, 2.5, 3.2, 4.0]
        
        bell_pan = random.uniform(0.15, 0.85)
        
        for idx in range(start_idx, end_idx):
            bt = (idx - start_idx) / sample_rate
            bell_sample = 0.0
            for h_idx, ratio in enumerate(harmonics):
                freq = hz * ratio
                env = math.exp(-bt * decays[h_idx] * 1.8)
                # Subtle FM modulator for metallic texture
                fm = 0.18 * math.sin(2 * math.pi * (hz * 1.4) * bt) * math.exp(-bt * 3.5)
                bell_sample += math.sin(2 * math.pi * freq * bt + fm) * amps[h_idx] * env
                
            fade = min(1.0, bt / 0.004)
            bell_sample *= fade * vol
            
            left_channel[idx] += bell_sample * (1.0 - bell_pan)
            right_channel[idx] += bell_sample * bell_pan

    # ----------------------------------------------------
    # TRACK 3: Tension Swells (String Pads)
    # ----------------------------------------------------
    print("Generating tension swells...")
    # E minor (E3, G3, B3 -> 164.81, 196.00, 246.94 Hz)
    # F minor (F3, G#3, C4 -> 174.61, 207.65, 261.63 Hz)
    swells = [
        {"start": 5.0, "peak": 9.0, "end": 14.0, "freqs": [164.81, 196.00, 246.94], "midis": [52, 55, 59]},
        {"start": 17.0, "peak": 21.0, "end": 26.0, "freqs": [174.61, 207.65, 261.63], "midis": [53, 56, 60]}
    ]
    
    for sw in swells:
        s_start = int(sw["start"] * sample_rate)
        s_peak = int(sw["peak"] * sample_rate)
        s_end = int(sw["end"] * sample_rate)
        
        for m_pitch in sw["midis"]:
            swell_notes_meta.append({
                "time": sw["start"] * beats_per_second,
                "pitch": m_pitch,
                "duration": (sw["end"] - sw["start"]) * beats_per_second,
                "vel": 60
            })
            
        for idx in range(s_start, s_end):
            t = idx / sample_rate
            if idx < s_peak:
                env = (idx - s_start) / (s_peak - s_start)
            else:
                env = 1.0 - (idx - s_peak) / (s_end - s_peak)
            
            env = 0.5 * (1.0 - math.cos(env * math.pi))
            
            swell_sample = 0.0
            for f in sw["freqs"]:
                detune = 0.6 * math.sin(2 * math.pi * 3.5 * t)
                swell_sample += math.sin(2 * math.pi * (f + detune) * t)
                
            swell_sample = (swell_sample / 3.0) * env * 0.14
            pan = 0.5 + 0.25 * math.sin(2 * math.pi * 0.2 * t)
            left_channel[idx] += swell_sample * (1.0 - pan)
            right_channel[idx] += swell_sample * pan

    # ----------------------------------------------------
    # TRACK 4: Low-passed Industrial Heartbeat (Percussion)
    # ----------------------------------------------------
    print("Generating heartbeat percussion...")
    # Heartbeat times: every 4 seconds
    heartbeat_times = [0.2, 4.0, 8.0, 12.0, 16.0, 20.0, 24.0, 28.0]
    
    for hb_t in heartbeat_times:
        # Save meta (MIDI note 35 is Acoustic Bass Drum in GM)
        percussion_notes_meta.append({
            "time": hb_t * beats_per_second,
            "pitch": 35,
            "duration": 0.5 * beats_per_second,
            "vel": 90
        })
        # Double hit: "lub-dub"
        for offset in [0.0, 0.28]:
            hit_t = hb_t + offset
            start_idx = int(hit_t * sample_rate)
            end_idx = min(start_idx + int(0.4 * sample_rate), num_samples)
            
            for idx in range(start_idx, end_idx):
                bt = (idx - start_idx) / sample_rate
                # Pitch sweep from 65Hz down to 25Hz to simulate heavy chest pulse
                freq = 65.0 * math.exp(-bt * 22.0) + 25.0
                env = math.exp(-bt * 12.0)
                
                hb_val = math.sin(2 * math.pi * freq * bt) * env * 0.4
                
                # Pan slightly center-left for lub, center-right for dub
                pan = 0.45 if offset == 0.0 else 0.55
                left_channel[idx] += hb_val * (1.0 - pan)
                right_channel[idx] += hb_val * pan

    # ----------------------------------------------------
    # Save composition metadata to JSON & MIDI
    # ----------------------------------------------------
    composition_metadata = {
        "tempo_bpm": tempo_bpm,
        "duration_seconds": duration,
        "tracks": {
            "drone_bass": drone_notes_meta,
            "creepy_bells": melody_notes_meta,
            "tension_swells": swell_notes_meta,
            "heartbeat": percussion_notes_meta
        }
    }
    
    json_path = "sfx/horror_ost_melody.json"
    with open(json_path, "w") as jf:
        json.dump(composition_metadata, jf, indent=4)
        
    midi_path = "sfx/horror_ost_melody.mid"
    save_midi(midi_path, tempo_bpm, drone_notes_meta, melody_notes_meta, swell_notes_meta, percussion_notes_meta)

    # ----------------------------------------------------
    # POST-PROCESSING: Echo Delay & Bitcrusher
    # ----------------------------------------------------
    print("Applying delay effect & bitcrushing...")
    delay_sec = 0.65
    delay_samples = int(delay_sec * sample_rate)
    feedback = 0.42
    
    delay_buf_l = [0.0] * delay_samples
    delay_buf_r = [0.0] * delay_samples
    delay_ptr = 0
    
    for i in range(num_samples):
        delayed_l = delay_buf_l[delay_ptr]
        delayed_r = delay_buf_r[delay_ptr]
        
        out_l = left_channel[i] + delayed_l * feedback
        out_r = right_channel[i] + delayed_r * feedback
        
        delay_buf_l[delay_ptr] = left_channel[i] + delayed_r * 0.12
        delay_buf_r[delay_ptr] = right_channel[i] + delayed_l * 0.12
        delay_ptr = (delay_ptr + 1) % delay_samples
        
        out_l = max(-1.0, min(1.0, out_l))
        out_r = max(-1.0, min(1.0, out_r))
        
        left_channel[i] = round(out_l * 2048.0) / 2048.0
        right_channel[i] = round(out_r * 2048.0) / 2048.0

    # Loop Crossfade
    fade_len = int(2.0 * sample_rate)
    for i in range(fade_len):
        fade_out_factor = 1.0 - (i / fade_len)
        fade_in_factor = i / fade_len
        end_idx = num_samples - fade_len + i
        beg_idx = i
        
        l_blend = (left_channel[end_idx] * fade_out_factor) + (left_channel[beg_idx] * fade_in_factor)
        r_blend = (right_channel[end_idx] * fade_out_factor) + (right_channel[beg_idx] * fade_in_factor)
        
        left_channel[beg_idx] = l_blend
        right_channel[beg_idx] = r_blend
        
    final_samples = num_samples - fade_len

    # Save as WAV file
    temp_wav = "scripts/temp_ambient.wav"
    with wave.open(temp_wav, "wb") as wav_file:
        wav_file.setnchannels(2)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        
        for i in range(final_samples):
            l_val = int(left_channel[i] * 32760)
            r_val = int(right_channel[i] * 32760)
            data = struct.pack("<hh", l_val, r_val)
            wav_file.writeframesraw(data)

    # Convert WAV to MP3 using ffmpeg
    output_mp3 = "sfx/placeholder_ambience.mp3"
    cmd = [
        "ffmpeg", "-y",
        "-i", temp_wav,
        "-codec:a", "libmp3lame",
        "-b:a", "96k",
        output_mp3
    ]
    
    try:
        subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        print("MP3 generation complete!")
    except subprocess.CalledProcessError as e:
        print(f"Error calling ffmpeg: {e.stderr.decode('utf-8', errors='ignore')}")
    finally:
        if os.path.exists(temp_wav):
            os.remove(temp_wav)

if __name__ == "__main__":
    generate_horror_ost()
