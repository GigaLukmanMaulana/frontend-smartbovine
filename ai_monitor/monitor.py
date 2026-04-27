# -*- coding: utf-8 -*-
"""
SmartBovine AI Monitor - Background Push Notification Service
=============================================================
CARA MENJALANKAN:
  1. Buka terminal / PowerShell
  2. Jalankan perintah ini:
     & c:/laragon/www/ai_sapi/venv/Scripts/python.exe c:/laragon/www/frontsapi/ai_monitor/monitor.py

  PENTING: Harus pakai Python dari VENV (ai_sapi/venv), BUKAN Python sistem!

CARA TEST NOTIFIKASI:
  & c:/laragon/www/ai_sapi/venv/Scripts/python.exe c:/laragon/www/frontsapi/ai_monitor/monitor.py --test

CARA MENDAPATKAN TOKEN:
  Token FCM otomatis muncul di log Flutter saat app dijalankan.
  Cari baris: [FCM] Device Token: xxxxx
  Lalu paste token tersebut di variabel DEVICE_TOKENS di bawah.
"""

import sys
import io
import warnings
import pandas as pd
import time
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace', line_buffering=True)
warnings.filterwarnings('ignore', category=UserWarning, module='sklearn')

import firebase_admin
from firebase_admin import credentials, db, messaging
import pickle
import numpy as np
import time
import json
import os
import math
from datetime import datetime

# ========================
# KONFIGURASI
# ========================
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SERVICE_ACCOUNT_PATH = os.path.join(SCRIPT_DIR, 'serviceAccountKey.json')
DATABASE_URL = 'https://smartsapi-default-rtdb.asia-southeast1.firebasedatabase.app/'
MODEL_PATH = os.path.join(SCRIPT_DIR, 'model_kesehatan.pkl')

# Topic FCM
FCM_TOPIC = 'peringatan_sapi'

# ========================
# DEVICE TOKENS - PASTE TOKEN HP ANDA DI SINI
# ========================
# Token didapat dari log Flutter: [FCM] Device Token: xxxxx
# Bisa tambah banyak token (banyak HP) di list ini
DEVICE_TOKENS = [
    'c7KEk7l7R7e_qYWsDukWyw:APA91bEOCIftDbkIrQcApJ2bLxDe3Z1iH-vvTJKSwJ3WuZwIPnbydmipXokUPMhE01x2dU_ktdOWezxuFn5SZ-8tBUa5xiuDQZN-Bm7vU1kj1f7sVmE7lls',
]

# Node sapi yang dipantau (tambah jika ada sapi baru)
SAPI_NODES = ['sapi_1', 'sapi_2', 'sapi_3']

# ========================
# INISIALISASI
# ========================
print("=" * 50)
print("   SmartBovine AI Monitor")
print("   Push Notification Service")
print("=" * 50)

# Init Firebase Admin SDK
cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
firebase_admin.initialize_app(cred, {
    'databaseURL': DATABASE_URL
})
print("[OK] Firebase Admin SDK terhubung")

# Load AI Model
with open(MODEL_PATH, 'rb') as f:
    model_kesehatan = pickle.load(f)
print("[OK] Model AI (Random Forest) dimuat")
print(f"[OK] Device tokens terdaftar: {len(DEVICE_TOKENS)} HP")

# Simpan status terakhir tiap sapi agar tidak kirim notif berulang
last_status = {}

# Simpan status geofence terakhir tiap sapi
last_geofence_status = {}

# ========================
# FUNGSI HITUNG JARAK (HAVERSINE)
# ========================
def hitung_jarak_km(lat1, lon1, lat2, lon2):
    """Hitung jarak antara 2 titik GPS dalam kilometer (rumus Haversine)"""
    R = 6371  # Radius bumi dalam kilometer
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat/2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon/2)**2
    c = 2 * math.asin(math.sqrt(a))
    return R * c

def ambil_konfig_kandang():
    """Ambil konfigurasi geofence dari Firebase"""
    try:
        konfig_ref = db.reference('konfig_kandang')
        konfig = konfig_ref.get()
        if konfig and isinstance(konfig, dict):
            lat = float(konfig.get('lat_pusat', 0))
            lng = float(konfig.get('lng_pusat', 0))
            radius = float(konfig.get('radius_km', 5))
            return lat, lng, radius
    except Exception as e:
        print(f"[WARN] Gagal baca konfig_kandang: {e}")
    return None, None, None

# ========================
# FUNGSI PREDIKSI AI
# ========================
def predict_kesehatan(sensor_data):
    """Prediksi status kesehatan berdasarkan data sensor"""
    try:
        features = [[
            float(sensor_data.get('suhu', 0)),
            float(sensor_data.get('suhu_lingkungan', 0)),
            float(sensor_data.get('lembap', 0)),
            float(sensor_data.get('acc_x', 0)),
            float(sensor_data.get('acc_y', 0)),
            float(sensor_data.get('acc_z', 0)),
            float(sensor_data.get('gyro_x', 0)),
            float(sensor_data.get('gyro_y', 0)),
            float(sensor_data.get('gyro_z', 0))
        ]]
        
        kolom_fitur = ['suhu', 'suhu_lingkungan', 'lembap', 'acc_x', 'acc_y', 'acc_z', 'gyro_x', 'gyro_y', 'gyro_z']
        df_features = pd.DataFrame(features, columns=kolom_fitur)
        result = model_kesehatan.predict(df_features)[0]
        return result
    except Exception as e:
        print(f"[ERROR] Gagal prediksi: {e}")
        return None

# ========================
# FUNGSI KIRIM NOTIFIKASI
# ========================
def kirim_notifikasi(sapi_id, status, suhu):
    """Kirim push notification ke semua device token + topic"""
    try:
        if status == 'Sakit':
            title = 'PERINGATAN: Sapi Terindikasi Sakit!'
            body = f'{sapi_id} - Suhu: {suhu} C. AI mendeteksi kondisi tidak normal. Segera periksa!'
        elif status == 'Heat Stress':
            title = 'PERINGATAN: Heat Stress Terdeteksi!'
            body = f'{sapi_id} - Suhu: {suhu} C. Sapi mengalami tekanan panas.'
        elif status == 'Keluar Area':
            title = 'PERINGATAN: Sapi Keluar Area Kandang!'
            body = f'{sapi_id} - Jarak: {suhu} KM dari pusat kandang. Segera cek lokasi!'
        else:
            return None

        waktu = datetime.now().strftime('%H:%M:%S')
        success_count = 0

        # === KIRIM KE SETIAP DEVICE TOKEN (LANGSUNG) ===
        for token in DEVICE_TOKENS:
            try:
                message = messaging.Message(
                    notification=messaging.Notification(
                        title=title,
                        body=body,
                    ),
                    android=messaging.AndroidConfig(
                        priority='high',
                        notification=messaging.AndroidNotification(
                            title=title,
                            body=body,
                            channel_id='smartbovine_alerts',
                            priority='max',
                            default_sound=True,
                            default_vibrate_timings=True,
                            notification_count=1,
                        ),
                    ),
                    data={
                        'status': status,
                        'suhu': str(suhu),
                        'sapi_id': sapi_id,
                        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
                        'timestamp': str(int(time.time() * 1000)),
                    },
                    token=token,  # Kirim langsung ke device
                )
                response = messaging.send(message)
                success_count += 1
                print(f"[{waktu}] [SENT] Token: ...{token[-20:]} -> {response}")
            except Exception as e:
                print(f"[{waktu}] [FAIL] Token: ...{token[-20:]} -> {e}")

        # === KIRIM KE TOPIC (BACKUP) ===
        try:
            message_topic = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                android=messaging.AndroidConfig(
                    priority='high',
                    notification=messaging.AndroidNotification(
                        channel_id='smartbovine_alerts',
                        priority='max',
                        default_sound=True,
                    ),
                ),
                data={
                    'status': status,
                    'suhu': str(suhu),
                    'sapi_id': sapi_id,
                    'timestamp': str(int(time.time() * 1000)),
                },
                topic=FCM_TOPIC,
            )
            response_topic = messaging.send(message_topic)
            print(f"[{waktu}] [SENT] Topic '{FCM_TOPIC}' -> {response_topic}")
        except Exception as e:
            print(f"[{waktu}] [FAIL] Topic -> {e}")

        print(f"[{waktu}] [NOTIF] {title}")
        print(f"         {body}")
        print(f"         Berhasil kirim ke {success_count}/{len(DEVICE_TOKENS)} device")
        return True
    except Exception as e:
        print(f"[ERROR] Gagal kirim notifikasi: {e}")
        return None

# ========================
# LISTENER FIREBASE
# ========================
def on_sensor_change(event):
    """Callback ketika ada perubahan data sensor di Firebase"""
    path = event.path
    data = event.data

    if data is None:
        return

    parts = path.strip('/').split('/')
    if len(parts) == 0:
        return

    sapi_key = parts[0]

    # Hanya proses node sapi yang terdaftar
    if sapi_key not in SAPI_NODES:
        return

    # Ambil data lengkap sapi ini dari Firebase
    ref = db.reference(sapi_key)
    sensor_data = ref.get()

    if sensor_data is None or not isinstance(sensor_data, dict):
        return

    if 'suhu' not in sensor_data:
        return

    suhu = sensor_data.get('suhu', 0)
    nama_sapi = sensor_data.get('nama_sapi', sapi_key)

    # Prediksi AI
    status = predict_kesehatan(sensor_data)

    if status is None:
        return

    waktu_str = datetime.now().strftime('%H:%M:%S')
    print(f"[{waktu_str}] [{sapi_key}] Suhu: {suhu} C -> AI: {status}")

    # Timestamp waktu ini
    current_time = time.time()
    
    # Kirim notifikasi jika status baru MERUPAKAN Sakit/Heat Stress DAN (status berubah ATAU jeda waktu sudah > 5 menit sejak terakhir peringatan)
    prev_status = last_status.get(sapi_key, {}).get('status', 'Sehat')
    last_notif_time = last_status.get(sapi_key, {}).get('time', 0)

    if status in ['Sakit', 'Heat Stress']:
        if status != prev_status or (current_time - last_notif_time > 300): # 300 detik = 5 menit
            result = kirim_notifikasi(nama_sapi, status, suhu)

            if result:
                # Simpan riwayat ke Firebase
                notif_ref = db.reference('notifikasi')
                notif_ref.push({
                    'sapi_id': sapi_key,
                    'nama_sapi': nama_sapi,
                    'status': status,
                    'suhu': suhu,
                    'timestamp': {'.sv': 'timestamp'},
                    'dibaca': False,
                })
                print(f"         [SAVE] Riwayat notifikasi disimpan ke Firebase")
            
            # Update memori pengiriman terakhir
            last_status[sapi_key] = {'status': status, 'time': current_time}
        else:
            # Tetap update statusnya tanpa mengubah waktu terakhir notif terkirim (sedang masa cooldown)
            last_status[sapi_key]['status'] = status

    elif status == 'Sehat':
        if prev_status in ['Sakit', 'Heat Stress']:
            print(f"[{waktu_str}] [OK] [{sapi_key}] Status kembali SEHAT (sebelumnya: {prev_status})")
        last_status[sapi_key] = {'status': status, 'time': 0}

# ========================
# FUNGSI TEST NOTIFIKASI
# ========================
def test_notifikasi():
    """Test kirim notifikasi langsung untuk debugging"""
    print("\n" + "=" * 50)
    print("   MODE TEST NOTIFIKASI")
    print("=" * 50)

    # Test 1: Baca data Firebase
    print("\n--- Test 1: Baca data sapi_1 ---")
    ref = db.reference('sapi_1')
    data = ref.get()
    if data:
        print(f"Data: {data}")
        suhu = data.get('suhu', 'TIDAK ADA')
        print(f"Suhu saat ini: {suhu}")
    else:
        print("Data sapi_1 TIDAK DITEMUKAN di Firebase!")

    # Test 2: Prediksi AI
    if data:
        print("\n--- Test 2: Prediksi AI ---")
        status = predict_kesehatan(data)
        print(f"Hasil prediksi: {status}")

    # Test 3: Kirim notifikasi ke semua device
    print("\n--- Test 3: Kirim notifikasi ke device ---")
    print(f"Jumlah device tokens: {len(DEVICE_TOKENS)}")
    for i, token in enumerate(DEVICE_TOKENS):
        print(f"  Token {i+1}: ...{token[-30:]}")

    kirim_notifikasi('Sapi Test', 'Sakit', 999)

    # Test 4: Simpan ke Firebase
    print("\n--- Test 4: Simpan riwayat ke Firebase ---")
    try:
        notif_ref = db.reference('notifikasi')
        result = notif_ref.push({
            'sapi_id': 'sapi_1',
            'nama_sapi': 'Sapi Test',
            'status': 'Sakit',
            'suhu': 999,
            'timestamp': {'.sv': 'timestamp'},
            'dibaca': False,
        })
        print(f"[OK] Riwayat disimpan, key: {result.key}")
    except Exception as e:
        print(f"[GAGAL] {e}")

    print("\n" + "=" * 50)
    print("TEST SELESAI!")
    print("Cek HP Anda, notifikasi harus muncul.")
    print("Jika TIDAK muncul:")
    print("  1. Pastikan app Flutter sedang berjalan di HP")
    print("  2. Buka Settings HP > Apps > SmartBovine > Notifications > ON")
    print("  3. Pastikan token di DEVICE_TOKENS sudah benar")
    print("=" * 50)

# ========================
# MAIN
# ========================
if __name__ == '__main__':
    # Cek apakah mode test
    if '--test' in sys.argv:
        test_notifikasi()
    else:
        # Mode monitor normal
        print(f"\n[{datetime.now().strftime('%H:%M:%S')}] [ACTIVE] MONITOR AKTIF")
        print("[INFO] Mendengarkan perubahan data sensor dari Firebase...")
        print(f"[INFO] Memantau node: {SAPI_NODES}")
        print(f"[INFO] Kirim notif ke {len(DEVICE_TOKENS)} device + topic '{FCM_TOPIC}'")
        print("[INFO] Tekan Ctrl+C untuk menghentikan\n")

        # Listen ke SETIAP node sapi secara terpisah (lebih reliable daripada listen root '/')
        def buat_listener(sapi_key):
            """Buat listener callback untuk satu sapi"""
            def listener(event):
                waktu_str = datetime.now().strftime('%H:%M:%S')
                
                # Ambil data lengkap sapi ini
                ref = db.reference(sapi_key)
                sensor_data = ref.get()

                if sensor_data is None or not isinstance(sensor_data, dict):
                    return

                suhu = sensor_data.get('suhu', 0)
                nama_sapi = sensor_data.get('nama_sapi', sapi_key)
                current_time = time.time()

                # =============================================
                # BAGIAN 1: PREDIKSI AI KESEHATAN
                # =============================================
                if 'suhu' in sensor_data:
                    status = predict_kesehatan(sensor_data)
                    if status is not None:
                        print(f"[{waktu_str}] [{sapi_key}] Suhu: {suhu} C -> AI: {status}")
                        prev_status = last_status.get(sapi_key, {}).get('status', 'Sehat')
                        last_notif_time = last_status.get(sapi_key, {}).get('time', 0)
                        if status in ['Sakit', 'Heat Stress']:
                            if status != prev_status or (current_time - last_notif_time > 300):
                                result = kirim_notifikasi(nama_sapi, status, suhu)
                                if result:
                                    notif_ref = db.reference('notifikasi')
                                    notif_ref.push({
                                        'sapi_id': sapi_key,
                                        'nama_sapi': nama_sapi,
                                        'status': status,
                                        'suhu': suhu,
                                        'timestamp': {'.sv': 'timestamp'},
                                        'dibaca': False,
                                    })
                                    print(f"         [SAVE] Riwayat disimpan ke Firebase")
                                last_status[sapi_key] = {'status': status, 'time': current_time}
                            else:
                                last_status[sapi_key]['status'] = status
                        elif status == 'Sehat':
                            if prev_status in ['Sakit', 'Heat Stress']:
                                print(f"[{waktu_str}] [OK] [{sapi_key}] Kembali SEHAT")
                            last_status[sapi_key] = {'status': status, 'time': 0}

                # =============================================
                # CEK GEOFENCING (KELUAR AREA KANDANG)
                # =============================================
                lat_sapi = sensor_data.get('latitude', None)
                lon_sapi = sensor_data.get('longitude', None)

                if lat_sapi is not None and lon_sapi is not None:
                    lat_pusat, lng_pusat, radius_km = ambil_konfig_kandang()

                    if lat_pusat is not None and lng_pusat is not None:
                        jarak = hitung_jarak_km(lat_pusat, lng_pusat, float(lat_sapi), float(lon_sapi))
                        keluar_pagar = jarak > radius_km

                        prev_geo = last_geofence_status.get(sapi_key, {}).get('keluar', False)
                        last_geo_time = last_geofence_status.get(sapi_key, {}).get('time', 0)

                        if keluar_pagar:
                            print(f"[{waktu_str}] [GEOFENCE] [{sapi_key}] Jarak: {jarak:.2f} KM -> KELUAR AREA!")
                            if not prev_geo or (current_time - last_geo_time > 300):
                                result = kirim_notifikasi(nama_sapi, 'Keluar Area', f'{jarak:.2f}')
                                if result:
                                    notif_ref = db.reference('notifikasi')
                                    notif_ref.push({
                                        'sapi_id': sapi_key,
                                        'nama_sapi': nama_sapi,
                                        'status': 'Keluar Area',
                                        'suhu': round(jarak, 2),
                                        'timestamp': {'.sv': 'timestamp'},
                                        'dibaca': False,
                                    })
                                    print(f"         [SAVE] Riwayat geofence disimpan ke Firebase")
                                last_geofence_status[sapi_key] = {'keluar': True, 'time': current_time}
                        else:
                            if prev_geo:
                                print(f"[{waktu_str}] [GEOFENCE OK] [{sapi_key}] Kembali ke area kandang ({jarak:.2f} KM)")
                            last_geofence_status[sapi_key] = {'keluar': False, 'time': 0}

            return listener

        for sapi in SAPI_NODES:
            ref = db.reference(sapi)
            ref.listen(buat_listener(sapi))
            print(f"[LISTEN] Memantau node: {sapi}")

        # Keep alive
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            print(f"\n[{datetime.now().strftime('%H:%M:%S')}] [STOPPED] MONITOR DIHENTIKAN")

