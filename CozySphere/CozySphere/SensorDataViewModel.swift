//
//  SensorDataViewModel.swift
//  CozySphere
//
//  Created by 少爷只做白日梦 on 2024/12/7.
//
import SwiftUI

class SensorDataViewModel: ObservableObject {
    @Published var latestTemperature: Double?
    @Published var latestHumidity: Double?
    @Published var errorMessage: String?

    func fetchLatestData() {
        APIManager.shared.fetchLatestSensorData { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    self?.latestTemperature = data["temperature"] as? Double
                    self?.latestHumidity = data["humidity"] as? Double
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

