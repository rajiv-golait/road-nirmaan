import os
import re

dashboard_dir = r"s:\RN\Road_Nirman-main\lib\screens\dashboards"

init_state_injection = """
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final email = AuthService.currentUserEmail ?? '';
      final profile = await UserService.instance.getCurrentProfile();
      final officialRole = await UserService.instance.getOfficialRoleByEmail(email);
      
      if (mounted) {
        setState(() {
          _userProfile = {
            'name': profile != null ? profile['full_name'] : email.split('@')[0].capitalize(),
            'mobile': profile != null && profile['mobile'] != null ? profile['mobile'] : '',
            'email': email,
            'role': officialRole != null ? officialRole['role'] : (profile != null ? profile['role'] : 'Citizen'),
          };
        });
      }
    } catch (e) {
      debugPrint('Profile load error: $e');
    }
  }
"""

# Helper function
capitalize_extension = """
extension StringExtension on String {
  String capitalize() {
    if (this.isEmpty) return this;
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}
"""

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # If already patched, skip
    if "_loadProfile" in content:
        return False

    # Ensure AuthService and UserService are imported
    if "import '../../utils/demo_role_router.dart';" not in content:
        content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport '../../utils/demo_role_router.dart';\nimport '../../services/user_service.dart';")

    if "StringExtension" not in content:
        content += "\n" + capitalize_extension

    # Inject initState into _ProfileViewState
    view_state_pattern = r"(class _ProfileViewState extends State<_ProfileView> \{)"
    content = re.sub(view_state_pattern, r"\1" + init_state_injection, content, count=1)

    # 1. Replace the name Text widget exactly:
    # const Text('Name', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),)
    # The name can be anything.
    name_pattern = r"const\s+Text\(\s*'([^']*)',\s*style:\s*const?\s*TextStyle\(\s*fontSize:\s*22,\s*fontWeight:\s*FontWeight\.bold,\s*color:\s*textPrimary,?\s*\),?\s*\)"
    content = re.sub(name_pattern, r"Text( _userProfile?['name']?.toString() ?? '\1', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary) )", content)

    # Note: Commissioner uses `TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary)` without `const` on the style, because it has `const Text(... style: TextStyle(...))`
    name_pattern2 = r"const\s+Text\(\s*'([^']*)',\s*style:\s*TextStyle\(\s*fontSize:\s*22,\s*fontWeight:\s*FontWeight\.bold,\s*color:\s*textPrimary,?\s*\),?\s*\)"
    content = re.sub(name_pattern2, r"Text( _userProfile?['name']?.toString() ?? '\1', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary) )", content)

    # 2. Replace the mobile/subtitle Text widget:
    mobile_pattern = r"const\s+Text\(\s*'([+\d\s]+)',\s*style:\s*const?\s*TextStyle\(color:\s*textSecondary,\s*fontSize:\s*15\),?\s*\)"
    content = re.sub(mobile_pattern, r"Text( _userProfile?['mobile']?.toString() ?? '\1', style: const TextStyle(color: textSecondary, fontSize: 15) )", content)

    mobile_pattern2 = r"const\s+Text\(\s*'([+\d\s]+)',\s*style:\s*TextStyle\(color:\s*textSecondary,\s*fontSize:\s*15\),?\s*\)"
    content = re.sub(mobile_pattern2, r"Text( _userProfile?['mobile']?.toString() ?? '\1', style: const TextStyle(color: textSecondary, fontSize: 15) )", content)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    
    return True

for filename in os.listdir(dashboard_dir):
    if filename.endswith("_dashboard.dart"):
        filepath = os.path.join(dashboard_dir, filename)
        if process_file(filepath):
            print(f"Patched {filename}")
        else:
            print(f"Skipped {filename}")
