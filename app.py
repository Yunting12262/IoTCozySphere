from flask import Flask, request, jsonify
from pymongo import MongoClient
from datetime import datetime, timedelta
import os

app = Flask(__name__)

# MongoDB 连接
client = MongoClient("mongodb+srv://ytzhu:Zyt1226%3D@cluster0.gzlq4.mongodb.net/?retryWrites=true&w=majority")
db = client["temperature_humidity_db"]
collection = db["sensor_data"]

@app.route('/api/post_data', methods=['POST'])
def receive_data():
    try:
        data = request.get_json()
        data['timestamp'] = datetime.utcnow()  # 添加时间戳
        collection.insert_one(data)
        return jsonify({"status": "success"}), 201
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 400

# 获取最新数据的 API
@app.route('/api/data/latest', methods=['GET'])
def get_latest_data():
    latest_data = collection.find().sort("timestamp", -1).limit(1)
    response_data = []
    for data in latest_data:
        data["_id"] = str(data["_id"])  # 将 ObjectId 转为字符串
        response_data.append(data)
    return jsonify(response_data)

# 获取每小时的平均温湿度
@app.route('/api/data/hourly_avg', methods=['GET'])
def get_hourly_avg():
    try:
        now = datetime.utcnow()
        one_day_ago = now - timedelta(days=1)
        
        # 聚合查询每小时的平均值
        pipeline = [
            {"$match": {"timestamp": {"$gte": one_day_ago, "$lte": now}}},
            {
                "$group": {
                    "_id": {
                        "year": {"$year": "$timestamp"},
                        "month": {"$month": "$timestamp"},
                        "day": {"$dayOfMonth": "$timestamp"},
                        "hour": {"$hour": "$timestamp"}
                    },
                    "avg_temperature": {"$avg": "$temperature"},
                    "avg_humidity": {"$avg": "$humidity"}
                }
            },
            {"$sort": {"_id": 1}}
        ]
        
        result = list(collection.aggregate(pipeline))
        return jsonify(result)
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

# 获取每天的平均温湿度
@app.route('/api/data/daily_avg', methods=['GET'])
def get_daily_avg():
    try:
        now = datetime.utcnow()
        thirty_days_ago = now - timedelta(days=30)

        # 聚合查询每天的平均值
        pipeline = [
            {"$match": {"timestamp": {"$gte": thirty_days_ago, "$lte": now}}},
            {
                "$group": {
                    "_id": {
                        "year": {"$year": "$timestamp"},
                        "month": {"$month": "$timestamp"},
                        "day": {"$dayOfMonth": "$timestamp"}
                    },
                    "avg_temperature": {"$avg": "$temperature"},
                    "avg_humidity": {"$avg": "$humidity"}
                }
            },
            {"$sort": {"_id": 1}}
        ]
        
        result = list(collection.aggregate(pipeline))
        return jsonify(result)
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


models = {}
for relay in ['fan', 'heater', 'humidifier']:
    model_path = f'{relay}_relay_model.pkl'
    if os.path.exists(model_path):
        with open(model_path, 'rb') as model_file:
            models[relay] = pickle.load(model_file)

@app.route('/api/predict_relay/<relay_type>', methods=['GET'])
def predict_relay(relay_type):
    if relay_type not in models:
        return jsonify({"status": "error", "message": "Invalid relay type."}), 400

    try:
        # 从请求中获取温湿度和时间信息
        temperature = request.args.get('temperature', type=float)
        humidity = request.args.get('humidity', type=float)
        hour = request.args.get('hour', type=int)
        day_of_week = request.args.get('day_of_week', type=int)
        month = request.args.get('month', type=int)
        air_quality = request.args.get('air_quality', type=int)
        is_home = request.args.get('is_home', type=int)

        # 验证请求参数是否完整
        if None in [temperature, humidity, hour, day_of_week, month, air_quality, is_home]:
            return jsonify({"status": "error", "message": "Missing required parameters."}), 400

        # 使用对应模型进行预测
        input_features = np.array([[temperature, humidity, hour, day_of_week, month, is_home, air_quality, 
                                    temperature, humidity, 0, 0]])
        model = models[relay_type]
        predicted_state = model.predict(input_features)[0]

        return jsonify({"relay": relay_type, "status": "ON" if predicted_state == 1 else "OFF"})
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500





# 阈值存储
settings = {
    "temp_threshold_high": 30.0,
    "hum_threshold_low": 50.0
}

# 接收传感器数据并检查是否需要更新固件
@app.route('/api/post_data', methods=['POST'])
def receive_data():
    try:
        data = request.get_json()
        data['timestamp'] = datetime.utcnow()  # 添加时间戳
        collection.insert_one(data)

        # 检查是否需要更新固件
        update_required = os.path.exists('firmware.bin')  # 检查固件文件是否存在
        if update_required:
            firmware_url = request.host_url + 'api/firmware'  # 动态生成固件下载链接
            return jsonify({"status": "success", "update_required": True, "firmware_url": firmware_url}), 201
        else:
            return jsonify({"status": "success", "update_required": False}), 201
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 400

# 获取和修改温湿度阈值
@app.route('/api/settings', methods=['GET', 'POST'])
def manage_settings():
    if request.method == 'GET':
        return jsonify(settings)
    elif request.method == 'POST':
        try:
            data = request.get_json()
            if "temp_threshold_high" in data:
                settings["temp_threshold_high"] = float(data["temp_threshold_high"])
            if "hum_threshold_low" in data:
                settings["hum_threshold_low"] = float(data["hum_threshold_low"])
            return jsonify({"status": "success", "settings": settings})
        except Exception as e:
            return jsonify({"status": "error", "message": str(e)}), 400
# 阈值存储
settings = {
    "temp_threshold_high": 30.0,
    "hum_threshold_low": 50.0
}

# 模式存储
modes = {
    "Work Mode": {"temp_threshold_high": 25.0, "hum_threshold_low": 40.0},
    "Entertainment Mode": {"temp_threshold_high": 27.0, "hum_threshold_low": 45.0},
    "Relax Mode": {"temp_threshold_high": 23.0, "hum_threshold_low": 50.0},
    "Sleep Mode": {"temp_threshold_high": 20.0, "hum_threshold_low": 55.0},
    "Reading Mode": {"temp_threshold_high": 24.0, "hum_threshold_low": 50.0},
}

# 当前激活的模式
current_mode = "Work Mode"

@app.route('/api/modes', methods=['GET'])
def get_modes():
    """
    获取所有模式及当前激活的模式。
    """
    return jsonify({"current_mode": current_mode, "modes": modes})

@app.route('/api/modes/<mode_name>', methods=['POST'])
def update_mode_settings(mode_name):
    """
    修改指定模式的温湿度设置。
    """
    if mode_name not in modes:
        return jsonify({"status": "error", "message": "Mode not found"}), 404

    try:
        data = request.get_json()
        if "temp_threshold_high" in data:
            modes[mode_name]["temp_threshold_high"] = float(data["temp_threshold_high"])
        if "hum_threshold_low" in data:
            modes[mode_name]["hum_threshold_low"] = float(data["hum_threshold_low"])
        return jsonify({"status": "success", "mode": modes[mode_name]})
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 400

@app.route('/api/modes/activate/<mode_name>', methods=['POST'])
def activate_mode(mode_name):
    """
    激活指定模式。
    """
    global current_mode
    if mode_name not in modes:
        return jsonify({"status": "error", "message": "Mode not found"}), 404

    current_mode = mode_name
    settings.update(modes[mode_name])  # 更新全局阈值为激活模式的设置
    return jsonify({"status": "success", "current_mode": current_mode, "settings": modes[current_mode]})

@app.route('/api/settings', methods=['GET', 'POST'])
def manage_settings():
    """
    获取或修改全局温湿度阈值。
    """
    if request.method == 'GET':
        return jsonify(settings)
    elif request.method == 'POST':
        try:
            data = request.get_json()
            if "temp_threshold_high" in data:
                settings["temp_threshold_high"] = float(data["temp_threshold_high"])
            if "hum_threshold_low" in data:
                settings["hum_threshold_low"] = float(data["hum_threshold_low"])
            return jsonify({"status": "success", "settings": settings})
        except Exception as e:
            return jsonify({"status": "error", "message": str(e)}), 400

# 接收传感器数据并检查是否需要更新固件
@app.route('/api/post_data', methods=['POST'])
def receive_data():
    try:
        data = request.get_json()
        data['timestamp'] = datetime.utcnow()  # 添加时间戳
        collection.insert_one(data)

        # 检查是否需要更新固件
        update_required = os.path.exists('firmware.bin')  # 检查固件文件是否存在
        if update_required:
            firmware_url = request.host_url + 'api/firmware'  # 动态生成固件下载链接
            return jsonify({"status": "success", "update_required": True, "firmware_url": firmware_url}), 201
        else:
            return jsonify({"status": "success", "update_required": False}), 201
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 400

# 提供固件文件下载
@app.route('/api/firmware', methods=['GET'])
def get_firmware():
    try:
        firmware_path = 'firmware.bin'  # 固件文件路径
        if os.path.exists(firmware_path):
            return send_file(firmware_path, as_attachment=True)
        else:
            return jsonify({"status": "error", "message": "Firmware not found."}), 404
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

# 上传新的固件文件
@app.route('/api/upload_firmware', methods=['POST'])
def upload_firmware():
    try:
        if 'firmware' not in request.files:
            return jsonify({"status": "error", "message": "No file part"}), 400
        file = request.files['firmware']
        if file.filename == '':
            return jsonify({"status": "error", "message": "No selected file"}), 400
        file.save('firmware.bin')
        return jsonify({"status": "success", "message": "Firmware uploaded successfully"}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
        
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, ssl_context=('cert.pem', 'key.pem'))