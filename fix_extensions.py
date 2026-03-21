import os
import re

dashboard_dir = r"s:\RN\Road_Nirman-main\lib\screens\dashboards"

ext_pattern = re.compile(r"extension StringExtension on String \{\s*String capitalize\(\) \{\s*if \(this\.isEmpty\) return this;\s*return \"\$\{this\[0\]\.toUpperCase\(\)\}\$\{this\.substring\(1\)\}\";\s*\}\s*\}", re.MULTILINE)

def fix_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Remove capitalize()
    new_content = content.replace(".capitalize()", "")
    
    # Remove extension
    new_content = ext_pattern.sub("", new_content)
    
    if content != new_content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Fixed {filepath}")

for filename in os.listdir(dashboard_dir):
    if filename.endswith("_dashboard.dart"):
        fix_file(os.path.join(dashboard_dir, filename))
