import os
import re

dashboard_dir = r"s:\RN\Road_Nirman-main\lib\screens\dashboards"

def fix_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # The buggy line: 'name': profile != null ? profile['full_name'] : email.split('@')[0],
    old_line = r"'name': profile != null \? profile\['full_name'\] : email\.split\('@'\)\[0\],"
    
    # We want: 
    # 'name': (profile != null && profile['full_name'] != null && profile['full_name'].toString().trim().isNotEmpty) ? profile['full_name'] : email.split('@')[0],
    
    new_line = r"'name': (profile != null && profile['full_name'] != null && profile['full_name'].toString().trim().isNotEmpty) ? profile['full_name'] : email.split('@')[0],"
    
    new_content = re.sub(old_line, new_line, content)
    
    if content != new_content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Fixed {filepath}")

for filename in os.listdir(dashboard_dir):
    if filename.endswith("_dashboard.dart"):
        fix_file(os.path.join(dashboard_dir, filename))
