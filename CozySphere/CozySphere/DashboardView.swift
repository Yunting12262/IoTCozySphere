//
//  DashboardView.swift
//  CozySphere
//
//  Created by 少爷只做白日梦 on 2024/11/19.
//

import SwiftUI

struct DashboardView: View {
    // 实时数据（从后端获取）
    @State private var actualTemperature: Double = 22
    @State private var actualHumidity: Double = 55
    @State private var airQuality: String = "Good"

    // 用户调整的目标值
    @State private var targetTemperature: Double = 22
    @State private var targetHumidity: Double = 55

    // 设备状态
    @State private var isHumidifierOn: Bool = false
    @State private var isHeaterOn: Bool = false
    @State private var isFanOn: Bool = false

    // 模式选择
    @State private var selectedMode: String = "Work Mode"
    let homeModes = ["Work Mode", "Entertainment Mode", "Relax Mode", "Sleep Mode", "Reading Mode"]

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 实时数据展示
                VStack(spacing: 15) {
                    Text("Dashboard")
                        .font(.title)
                        .fontWeight(.bold)

                    HStack {
                        VStack {
                            Text("Actual Temperature")
                                .font(.headline)
                            Text("\(Int(actualTemperature))°C")
                                .font(.title)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)

                        VStack {
                            Text("Actual Humidity")
                                .font(.headline)
                            Text("\(Int(actualHumidity))%")
                                .font(.title)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(10)

                        VStack {
                            Text("Air Quality")
                                .font(.headline)
                            Text(airQuality)
                                .font(.title)
                        }
                        .padding()
                        .background(Color.yellow.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
                .padding()

                // 模式选择
                VStack(alignment: .leading, spacing: 10) {
                    Text("Select Home Mode")
                        .font(.headline)

                    Menu {
                        ForEach(homeModes, id: \.self) { mode in
                            Button(action: {
                                selectedMode = mode
                                sendModeToBackend(mode: mode) // 发送模式到后端
                            }) {
                                Text(mode)
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedMode)
                                .foregroundColor(.black)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
                .padding()

                // 设置目标值
                VStack(alignment: .leading, spacing: 10) {
                    Text("Set Target Temperature and Humidity")
                        .font(.headline)

                    HStack {
                        Text("Target Temp: \(Int(targetTemperature))°C")
                        Spacer()
                        Stepper("", value: $targetTemperature, in: 15...30, step: 1, onEditingChanged: { _ in
                            sendTargetData() // 设置目标值 API 调用
                        })
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)

                    HStack {
                        Text("Target Humid: \(Int(targetHumidity))%")
                        Spacer()
                        Stepper("", value: $targetHumidity, in: 30...70, step: 1, onEditingChanged: { _ in
                            sendTargetData() // 设置目标值 API 调用
                        })
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }
                .padding()

                // 设备控制
                VStack(alignment: .leading, spacing: 10) {
                    Text("Device Control")
                        .font(.headline)

                    Toggle(isOn: $isHumidifierOn) {
                        Text("Humidifier")
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .onChange(of: isHumidifierOn) {
                        updateDeviceState(device: "humidifier", state: isHumidifierOn)
                    }

                    Toggle(isOn: $isHeaterOn) {
                        Text("Heater")
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .red))
                    .onChange(of: isHeaterOn) {
                        updateDeviceState(device: "heater", state: isHeaterOn)
                    }

                    Toggle(isOn: $isFanOn) {
                        Text("Fan")
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    .onChange(of: isFanOn) {
                        updateDeviceState(device: "fan", state: isFanOn)
                    }
                }
                .padding()

                Spacer()
            }
            .onAppear {
                fetchActualData() // 获取实时数据
            }
        }
    }

    // 获取实时数据的 API 调用
    private func fetchActualData() {
        guard let url = URL(string: "http://localhost:5001/api/data/latest") else {
            print("Invalid URL")
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                print("Error fetching data:", error)
                return
            }

            guard let data = data else {
                print("No data returned")
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]],
                   let latestData = json.first {
                    DispatchQueue.main.async {
                        actualTemperature = latestData["temperature"] as? Double ?? 22
                        actualHumidity = latestData["humidity"] as? Double ?? 55
                    }
                }
            } catch {
                print("Error decoding JSON:", error)
            }
        }.resume()
    }

    // 发送目标值到后端的 API 调用
    private func sendTargetData() {
        guard let url = URL(string: "http://localhost:5001/api/target_data") else {
            print("Invalid URL")
            return
        }

        let body: [String: Any] = [
            "target_temperature": targetTemperature,
            "target_humidity": targetHumidity
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            print("Error encoding JSON:", error)
            return
        }

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                print("Error sending target data:", error)
            } else {
                print("Target data sent successfully:", response ?? "No response")
            }
        }.resume()
    }

    // 更新设备状态的 API 调用
    private func updateDeviceState(device: String, state: Bool) {
        guard let url = URL(string: "http://localhost:5001/api/device_state") else {
            print("Invalid URL")
            return
        }

        let body: [String: Any] = [
            "device": device,
            "state": state
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            print("Error encoding JSON:", error)
            return
        }

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                print("Error updating device state:", error)
            } else {
                print("Device state updated successfully:", response ?? "No response")
            }
        }.resume()
    }

    // 发送模式选择到后端
    private func sendModeToBackend(mode: String) {
        guard let url = URL(string: "http://localhost:5001/api/mode") else {
            print("Invalid URL")
            return
        }

        let body: [String: Any] = ["mode": mode]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            print("Error encoding mode data:", error)
            return
        }

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                print("Error sending mode data:", error)
            } else {
                print("Mode sent successfully:", response ?? "No response")
            }
        }.resume()
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
    }
}
