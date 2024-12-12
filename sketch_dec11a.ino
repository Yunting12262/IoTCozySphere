#include <WiFi.h>
#include <HTTPClient.h>
#include <DHT.h>
#include <HTTPUpdate.h>
#include <ArduinoJson.h>

#define DHTPIN 4
#define DHTTYPE DHT22
#define RELAY1_PIN 2
#define RELAY2_PIN 5
#define MQ135_AO_PIN 36    // MQ-135 AO 
#define MQ135_DO_PIN 34    // MQ-135 DO 

const char* ssid = "VM4566838";
const char* password = "tt8dmVcvHfvx";

const char* serverName = "http://192.168.0.13:5001/api/post_data";
const char* updateUrl = "http://192.168.0.13:5001/api/firmware";
const char* settingsUrl = "http://192.168.0.13:5001/api/settings";
const char* apiKey = "test_password"; 

DHT dht(DHTPIN, DHTTYPE);

float tempThresholdHigh = 30.0;
float humThresholdLow = 50.0;
bool relay1State = false;
bool relay2State = false;

void setup() {
  Serial.begin(115200);
  dht.begin();
  pinMode(RELAY1_PIN, OUTPUT);
  pinMode(RELAY2_PIN, OUTPUT);
  pinMode(MQ135_DO_PIN, INPUT);  // MQ-135数字引脚
  digitalWrite(RELAY1_PIN, HIGH);
  digitalWrite(RELAY2_PIN, HIGH);

  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected.");
  Serial.println(WiFi.localIP());
}

void loop() {
  // 更新设定的温湿度阈值
  updateThresholds();

  float temp = dht.readTemperature();
  float hum = dht.readHumidity();
  int airQualityAnalog = analogRead(MQ135_AO_PIN);  // 模拟读取空气质量
  int airQualityDigital = digitalRead(MQ135_DO_PIN); // 数字读取空气质量

  if (!isnan(temp) && !isnan(hum)) {
    Serial.printf("Temperature: %.2f °C, Humidity: %.2f %%\n", temp, hum);
    Serial.printf("Air Quality (Analog): %d, Air Quality (Digital): %d\n", airQualityAnalog, airQualityDigital);

    // 控制继电器1（温度高时打开）
    if (temp >= tempThresholdHigh && !relay1State) {
      digitalWrite(RELAY1_PIN, LOW);
      relay1State = true;
      Serial.println("Relay 1 ON");
    } else if (temp < tempThresholdHigh && relay1State) {
      digitalWrite(RELAY1_PIN, HIGH);
      relay1State = false;
      Serial.println("Relay 1 OFF");
    }

    // 控制继电器2（湿度低时打开）
    if (hum <= humThresholdLow && !relay2State) {
      digitalWrite(RELAY2_PIN, LOW);
      relay2State = true;
      Serial.println("Relay 2 ON");
    } else if (hum > humThresholdLow && relay2State) {
      digitalWrite(RELAY2_PIN, HIGH);
      relay2State = false;
      Serial.println("Relay 2 OFF");
    }

    // 上传数据到服务器
    sendDataToServer(temp, hum, airQualityAnalog, airQualityDigital);

    // 检查是否需要更新固件
    checkForFirmwareUpdate();
  } else {
    Serial.println("Failed to read from DHT sensor!");
  }

  delay(2000);
}

void sendDataToServer(float temp, float hum, int airQualityAnalog, int airQualityDigital) {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    http.begin(serverName);
    http.addHeader("Content-Type", "application/json");

    String jsonData = "{"temperature":" + String(temp) +
                      ","humidity":" + String(hum) +
                      ","air_quality_analog":" + String(airQualityAnalog) +
                      ","air_quality_digital":" + String(airQualityDigital) + "}";

    int httpResponseCode = http.POST(jsonData);

    if (httpResponseCode > 0) {
      String response = http.getString();
      Serial.printf("HTTP Response code: %d\n", httpResponseCode);
      Serial.println("Response: " + response);
    } else {
      Serial.printf("Error code: %d\n", httpResponseCode);
    }

    http.end();
  } else {
    Serial.println("WiFi not connected.");
  }
}

void updateThresholds() {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    http.begin(settingsUrl);
    int httpResponseCode = http.GET();

    if (httpResponseCode == 200) {
      String payload = http.getString();
      DynamicJsonDocument doc(512);
      deserializeJson(doc, payload);

      tempThresholdHigh = doc["temp_threshold_high"];
      humThresholdLow = doc["hum_threshold_low"];

      Serial.printf("Updated thresholds - Temp: %.2f, Hum: %.2f\n", tempThresholdHigh, humThresholdLow);
    } else {
      Serial.printf("Failed to fetch thresholds, HTTP Response code: %d\n", httpResponseCode);
    }

    http.end();
  } else {
    Serial.println("WiFi not connected for updating thresholds.");
  }
}

void checkForFirmwareUpdate() {
  if (WiFi.status() == WL_CONNECTED) {
    t_httpUpdate_return result = httpUpdate.update(updateUrl);

    switch (result) {
      case HTTP_UPDATE_FAILED:
        Serial.printf("HTTP_UPDATE_FAILED Error (%d): %s\n", httpUpdate.getLastError(), httpUpdate.getLastErrorString().c_str());
        break;
      case HTTP_UPDATE_NO_UPDATES:
        Serial.println("No updates available.");
        break;
      case HTTP_UPDATE_OK:
        Serial.println("Update successful.");
        break;
    }
  } else {
    Serial.println("WiFi not connected for firmware update.");
  }
}

