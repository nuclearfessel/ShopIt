"""Installer scripts offer keep/clear choices for lists and settings."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
INSTALLER = ROOT / "installer"


class InstallDataChoiceTests(unittest.TestCase):
    def test_windows_setup_has_data_page_and_silent_flags(self):
        text = (INSTALLER / "shop_it.iss").read_text(encoding="utf-8")
        self.assertIn("CreateInputOptionPage", text)
        self.assertIn("Keep shopping lists, pantry, history, and recipes", text)
        self.assertIn("Keep settings (theme, sync code, tax, and sharing)", text)
        self.assertIn("/CLEAR_LISTS", text)
        self.assertIn("/CLEAR_SETTINGS", text)
        self.assertIn("/CLEAR_DATA", text)
        self.assertIn("ClearShopItLists", text)
        self.assertIn("ClearShopItSettings", text)
        self.assertIn("shared_preferences.json", text)
        self.assertIn("shop_it.sqlite", text)

    def test_mac_android_ios_helpers_prompt_for_data_choice(self):
        scripts = [
            INSTALLER / "Install-ShopIt.command",
            INSTALLER / "Install-ShopIt-Android.sh",
            INSTALLER / "Install-ShopIt-Android.ps1",
            INSTALLER / "Install-ShopIt-iOS.command",
        ]
        for path in scripts:
            text = path.read_text(encoding="utf-8")
            self.assertIn("Keep lists and settings", text, path.name)
            self.assertIn("Keep lists, reset settings", text, path.name)
            self.assertIn("Keep settings, clear lists", text, path.name)
            self.assertIn("Clear lists and settings", text, path.name)


if __name__ == "__main__":
    unittest.main()
