import SwiftUI

struct TutorialView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Сервер работает внутри телефона. Чтобы направить на него трафик, настройте прокси в Wi-Fi.")
                        .font(.footnote)
                }
                
                Section("Шаг 1. Запустите сервер") {
                    Text("Вернитесь на вкладку «Статус» и нажмите «Запустить сервер».")
                        .font(.callout)
                }
                
                Section("Шаг 2. Настройте Wi-Fi") {
                    Text("Настройки iOS → Wi-Fi.")
                    Text("Нажмите на синюю букву (i) рядом с вашей сетью.")
                    Text("Прокрутите вниз до «Настройка прокси».")
                    Text("Выберите «Вручную».")
                }
                
                Section("Шаг 3. Введите данные") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Сервер: 127.0.0.1")
                        Text("Порт: 8888")
                    }
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.blue)
                }
                
                Section("Шаг 4. Проверьте") {
                    Text("Сохраните настройки Wi-Fi. Откройте Safari или Chrome и зайдите на youtube.com. Если сайт открылся — значит, DPI обойден!")
                        .font(.footnote)
                }
            }
            .navigationTitle("Как включить")
        }
    }
}