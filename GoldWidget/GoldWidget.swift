import WidgetKit
import SwiftUI
import AppIntents
import UserNotifications

// 1. 数据模型（无需修改）
struct GoldPriceEntry: TimelineEntry {
    let date: Date
    let price: String
    let isError: Bool
}

// ==========================================
// 🌟 新增：交互与配置逻辑 (App Intents)
// ==========================================

// 2A. 手动刷新按钮的动作
struct RefreshGoldIntent: AppIntent {
    static var title: LocalizedStringResource = "手动刷新金价"
    
    func perform() async throws -> some IntentResult {
        // 当用户点击按钮执行此动作后，系统会自动重新拉取 getTimeline 刷新小组件
        return .result()
    }
}

// 2B. 小组件背面的用户设置页面
struct GoldConfigIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "金价提醒设置"
    static var description = IntentDescription("设置您的目标金价，达到后将发送全局通知。")
    
    @Parameter(title: "开启全局通知", default: false)
    var enableAlert: Bool
    
    @Parameter(title: "提醒目标价 (元/克)", default: 600.0)
    var targetPrice: Double
}

// ==========================================
// 🌟 新增：全局系统通知逻辑
// ==========================================
func sendAlertNotification(currentPrice: String) {
    let content = UNMutableNotificationContent()
    content.title = "⚠️ 纸黄金价格提醒"
    content.body = "当前金价已达到您的目标价：\(currentPrice) 元/克"
    content.sound = .default // 提示音
    
    // 使用随机标识符，确保每次都能弹出来
    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request) { error in
        if let error = error {
            print("通知发送失败: \(error)")
        }
    }
}

// 帮助函数：从 HTML 源码中安全提取价格（DOM 狙击版）
func safeExtractPrice(from html: String) -> String? {
    // 逻辑：直接匹配 id="activeprice_数字">价格<
    // 对应源码：<td align="center" id="activeprice_080020000521">967.42</td>
    
    let pattern = #"id="activeprice_\d+">([0-9]{3,4}\.[0-9]{2})<"#
    
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
        return nil
    }
    
    let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
    
    // 如果找到了对应的标签，直接提取组 1 (即括号里的价格数字)
    if let match = regex.firstMatch(in: html, options: [], range: nsRange) {
        if let priceRange = Range(match.range(at: 1), in: html) {
            return String(html[priceRange])
        }
    }
    
    return "解析DOM结构失败"
}

// 2. 数据获取与解析模块（安全强化版）
func fetchGoldPrice() async -> String? {
    let urlString = "https://mybank.icbc.com.cn/icbc/newperbank/perbank3/gold/goldaccrual_query_out.jsp"
    guard let url = URL(string: urlString) else { return nil }

    do {
        // 发起网络请求，为小组件设置 10 秒超时限制，防止死等
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        let (data, _) = try await URLSession.shared.data(for: request)

        // 【安全修复1：更稳健的解码机制】
        let cfEnc = CFStringEncodings.GB_18030_2000.rawValue
        let nsEnc = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(cfEnc))

        // 尝试用 GBK 解码
        guard let gbkHtml = String(data: data, encoding: String.Encoding(rawValue: nsEnc)) else {
            // 如果 GBK 解码直接 nil，说明这根本不是 JSP，是一个假网页。
            // 但如果之前成功过一次（如图，加载了时间），说明它是 JSP，但这次加载了奇怪的东西。
            // 为确保万无一失，我们此时不能 nil，要返回具体的解码失败字符串。
            let utf8Html = String(decoding: data, as: UTF8.self)
            return safeExtractPrice(from: utf8Html)
        }

        // 成功获取解码后的 HTML 字符串，进入核心解析环节
        if let price = safeExtractPrice(from: gbkHtml) {
            return price
        } else {
            // 关键字找到了，但找不到数字，说明网页价格结构变动
            return "关键字找到但无数字"
        }

    } catch {
        // 网络请求失败、超时或解码崩溃
        print("fetchGoldPrice error: \(error)")
        return "网络/解码错误" // 明确返回一个非 nil 的描述字符串
    }
}

// 3. 数据调度引擎（增强错误控制）
struct Provider: AppIntentTimelineProvider {
    
    func placeholder(in context: Context) -> GoldPriceEntry {
        GoldPriceEntry(date: Date(), price: "加载中...", isError: false)
    }

    func snapshot(for configuration: GoldConfigIntent, in context: Context) async -> GoldPriceEntry {
        GoldPriceEntry(date: Date(), price: "500.00", isError: false)
    }

    // 最核心的刷新逻辑（使用了最新版的 async/await 语法，更加简洁）
    func timeline(for configuration: GoldConfigIntent, in context: Context) async -> Timeline<GoldPriceEntry> {
        
        let price = await fetchGoldPrice()
        
        // 核心功能：通知判断逻辑
        if configuration.enableAlert,
           let priceStr = price,
           let currentPriceVal = Double(priceStr) {
            
            // 如果当前金价 大于或等于 用户设置的目标价，则发送通知！
            // （如果你想做“跌破”提醒，把 >= 改成 <= 即可）
            if currentPriceVal >= configuration.targetPrice {
                sendAlertNotification(currentPrice: priceStr)
            }
        }
        
        let isErrorResult = (price == "找不到关键字" || price == "关键字找到但无数字" || price == "网络/解码错误" || price == "解析DOM结构失败")
        
        let currentEntry = GoldPriceEntry(
            date: Date(),
            price: price ?? "未知",
            isError: isErrorResult
        )
        
        // 下次系统级自动更新定在 15 分钟后（系统底线限制）
        let nextUpdateDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        
        return Timeline(entries: [currentEntry], policy: .after(nextUpdateDate))
    }
}

// 4. UI 视图层（保持简洁，无需修改）
struct GoldWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            HStack {
                Text("工行纸黄金")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Spacer()
                
                // 【新增：手动刷新按钮】
                Button(intent: RefreshGoldIntent()) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                        .padding(4)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain) // 必须加这个，否则点击会触发整个 Widget 的点击事件
            }
            
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(entry.price)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(entry.isError ? .red : .primary)
                    .lineLimit(1)
                    // 稍微把底线放宽，允许数字缩小到原来的 40%
                    .minimumScaleFactor(0.4)
                
                if !entry.isError {
                    Text("元/克")
                        .font(.caption)
                        .foregroundColor(.gray)
                        // 【关键修复 1】：强制单位只能显示 1 行，绝不竖排
                        .lineLimit(1)
                        // 【关键修复 2】：锁定单位的横向宽度，打死不退让，逼迫前面的数字缩小
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            
            Spacer()
            
            Text("最后更新: \(entry.date, format: .dateTime.hour().minute().second())")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding()
        .containerBackground(.regularMaterial, for: .widget)
    }
}
