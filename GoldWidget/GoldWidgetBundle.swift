//
//  GoldWidgetBundle.swift
//  GoldWidget
//
//  Created by clintlin on 2026/3/24.
//

import WidgetKit
import SwiftUI

// 注册入口
@main
struct GoldWidget: Widget {
    let kind: String = "GoldWidgetV2"

    var body: some WidgetConfiguration {
        // 改为 AppIntentConfiguration 以支持用户配置
        AppIntentConfiguration(kind: kind, intent: GoldConfigIntent.self, provider: Provider()) { entry in
            GoldWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("实时金价")
        .description("追踪金价并支持阈值提醒。")
        .supportedFamilies([.systemSmall])
    }
}
