import re

def main():
    with open('SettingsView.swift', 'r') as f:
        content = f.read()

    # Remove the orphaned helpers: locationActionRow, calendarActionRow, openSettingsButton

    # 1. locationActionRow
    location_pattern = re.compile(r'    @ViewBuilder\n    private var locationActionRow: some View \{\n(?:.*\n)*?    \}\n\n', re.MULTILINE)
    content = location_pattern.sub('', content)

    # 2. calendarActionRow
    calendar_pattern = re.compile(r'    @ViewBuilder\n    private var calendarActionRow: some View \{\n(?:.*\n)*?    \}\n\n', re.MULTILINE)
    content = calendar_pattern.sub('', content)

    # 3. openSettingsButton
    open_settings_pattern = re.compile(r'    private func openSettingsButton\(title: String\) -> some View \{\n(?:.*\n)*?    \}\n\n', re.MULTILINE)
    content = open_settings_pattern.sub('', content)

    with open('SettingsView.swift', 'w') as f:
        f.write(content)

    print("Success")

if __name__ == "__main__":
    main()
