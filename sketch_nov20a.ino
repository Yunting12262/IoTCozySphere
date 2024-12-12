#include <WiFi.h>
#include <HTTPClient.h>
#include <DHT.h>
#include <ArduinoOTA.h>
#include <HTTPUpdate.h>

#define DHTPIN 4           // DHT22 数据引脚连接到 GPIO 4
#define DHTTYPE DHT22      // 定义传感器类型为 DHT22
#define RELAY1_PIN 2       // 继电器1控制引脚为 GPIO 2
#define RELAY2_PIN 5       // 继电器2控制引脚为 GPIO 5
#define RELAY1_STATUS_PIN 18 // 继电器1状态引脚
#define RELAY2_STATUS_PIN 19 // 继电器2状态引脚

#define MQ135_AO_PIN 36    // MQ-135 AO 引脚连接到 VP（GPIO 36）
#define MQ135_DO_PIN 34    // MQ-135 DO 引脚连接到 GPIO 34

// WiFi 连接参数
const char* ssid = "VM4566838";        // 替换为你的 WiFi SSID
const char* password = "tt8dmVcvHfvx";  // 替换为你的 WiFi 密码

// Flask 服务器地址
const char* serverName = "http://192.168.0.13:5001/api/post_data";  // 替换为你的 Flask 服务器数据上传地址
const char* updateUrl = "http://192.168.0.13:5001/api/firmware";    // 替换为你的 Flask 服务器固件更新地址

DHT dht(DHTPIN, DHTTYPE);  // 创建 DHT 传感器对象

float tempThresholdHigh = 30.0;  // 温度高阈值
float humThresholdLow = 50.0;    // 湿度低阈值
bool relay1State = false;         // 继电器1状态
bool relay2State = false;         // 继电器2状态

void setup() {
  Serial.begin(115200);            // 初始化串口通信，波特率为 115200
  dht.begin();                     // 初始化 DHT 传感器
  pinMode(RELAY1_PIN, OUTPUT);     // 设置继电器1控制引脚为输出模式
  pinMode(RELAY2_PIN, OUTPUT);     // 设置继电器2控制引脚为输出模式
  pinMode(RELAY1_STATUS_PIN, INPUT); // 设置继电器1状态引脚为输入模式
  pinMode(RELAY2_STATUS_PIN, INPUT); // 设置继电器2状态引脚为输入模式
  pinMode(MQ135_DO_PIN, INPUT);    // 设置 MQ-135 DO 引脚为输入模式
  digitalWrite(RELAY1_PIN, HIGH);  // 初始状态关闭继电器1
  digitalWrite(RELAY2_PIN, HIGH);  // 初始状态关闭继电器2

  // 连接 WiFi
  Serial.print("Connecting to WiFi");
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected.");
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());

  // 初始化 OTA 功能
  ArduinoOTA.onStart([]() {
    String type = (ArduinoOTA.getCommand() == U_FLASH) ? "sketch" : "filesystem";
    Serial.println("Start updating " + type);
  });
  ArduinoOTA.onEnd([]() {
    Serial.println("\nUpdate Complete");
  });
  ArduinoOTA.onProgress([](unsigned int progress, unsigned int total) {
    Serial.printf("Progress: %u%%\r", (progress / (total / 100)));
  });
  ArduinoOTA.onError([](ota_error_t error) {
    Serial.printf("Error[%u]: ", error);
    if (error == OTA_AUTH_ERROR) Serial.println("Auth Failed");
    else if (error == OTA_BEGIN_ERROR) Serial.println("Begin Failed");
    else if (error == OTA_CONNECT_ERROR) Serial.println("Connect Failed");
    else if (error == OTA_RECEIVE_ERROR) Serial.println("Receive Failed");
    else if (error == OTA_END_ERROR) Serial.println("End Failed");
  });
  ArduinoOTA.begin();
  Serial.println("OTA Ready");
  Serial.println("Starting temperature, humidity, and air quality monitoring...");
}

void loop() {
  // OTA 处理
  ArduinoOTA.handle();

  // 定期检查并更新固件
  checkForFirmwareUpdate();

  // 读取温湿度数据
  float temp = dht.readTemperature();  // 读取摄氏温度
  float hum = dht.readHumidity();      // 读取相对湿度

  if (isnan(temp) || isnan(hum)) {
    Serial.println("Failed to read from DHT sensor, please check wiring!");
  } else {
    Serial.print("Temperature: ");
    Serial.print(temp);
    Serial.print(" \u00b0C\tHumidity: ");
    Serial.print(hum);
    Serial.println(" %");

    // 控制继电器1逻辑（温度高时打开）
    if (temp >= tempThresholdHigh && !relay1State) {
      digitalWrite(RELAY1_PIN, LOW);
      relay1State = true;
      Serial.println("Temperature exceeds threshold! Relay 1 turned ON.");
    } else if (temp < tempThresholdHigh && relay1State) {
      digitalWrite(RELAY1_PIN, HIGH);
      relay1State = false;
      Serial.println("Temperature below threshold. Relay 1 turned OFF.");
    }

    // 控制继电器2逻辑（湿度低时打开）
    if (hum <= humThresholdLow && !relay2State) {
      digitalWrite(RELAY2_PIN, LOW);
      relay2State = true;
      Serial.println("Humidity below threshold! Relay 2 turned ON.");
    } else if (hum > humThresholdLow && relay2State) {
      digitalWrite(RELAY2_PIN, HIGH);
      relay2State = false;
      Serial.println("Humidity above threshold. Relay 2 turned OFF.");
    }
  }

  // 读取继电器状态
  bool relay1Status = digitalRead(RELAY1_STATUS_PIN);
  bool relay2Status = digitalRead(RELAY2_STATUS_PIN);
  Serial.print("Relay 1 Status: ");
  Serial.println(relay1Status ? "ON" : "OFF");
  Serial.print("Relay 2 Status: ");
  Serial.println(relay2Status ? "ON" : "OFF");

  // 读取 MQ-135 传感器数据
  int gasValue = analogRead(MQ135_AO_PIN);  // 从 VP（GPIO 36）读取模拟值
  Serial.print("Air Quality Level (Analog): ");
  Serial.println(gasValue);

  int airQuality = digitalRead(MQ135_DO_PIN); 
  if (airQuality == HIGH) {
    Serial.println("Air quality is good.");
  } else {
    Serial.println("Warning: Poor air quality detected!");
  }

  // 将数据发送到 Flask 服务器
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    http.begin(serverName);
    http.addHeader("Content-Type", "application/json");

    String jsonData = "{\"temperature\":" + String(temp) + ",\"humidity\":" + String(hum) + ",\"relay1_status\":" + String(relay1Status) + ",\"relay2_status\":" + String(relay2Status) + ",\"air_quality_analog\":" + String(gasValue) + ",\"air_quality_digital\":" + String(airQuality) + "}";

    int httpResponseCode = http.POST(jsonData);

    if (httpResponseCode > 0) {
      String response = http.getString();
      Serial.print("HTTP Response code: ");
      Serial.println(httpResponseCode);
      Serial.println("Response from server: " + response);
    } else {
      Serial.print("Error on sending POST: ");
      Serial.println(httpResponseCode);
    }

    http.end(); 
  } else {
    Serial.println("WiFi not connected");
  }

  delay(2000);
}

// 检查并更新固件
void checkForFirmwareUpdate() {
  if (WiFi.status() == WL_CONNECTED) {
    t_httpUpdate_return result = httpUpdate.update(updateUrl);
    switch (result) {
      case HTTP_UPDATE_FAILED:
        Serial.printf("HTTP Update failed. Error (%d): %s\n", httpUpdate.getLastError(), httpUpdate.getLastErrorString().c_str());
        break;
      case HTTP_UPDATE_NO_UPDATES:
        Serial.println("No updates available.");
        break;
      case HTTP_UPDATE_OK:
        Serial.println("Update successful!"); // ESP32 会自动重启
        break;
    }
  } else {
    Serial.println("WiFi not connected for firmware update.");
  }
}

