import importlib.machinery
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import unittest
from contextlib import redirect_stdout
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]


def load_script(name):
    loader = importlib.machinery.SourceFileLoader(name, str(ROOT / "bin" / name))
    spec = importlib.util.spec_from_loader(name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


aur_updates = load_script("aur-updates")
aur_changelog = load_script("aur-changelog")


class AurUpdatesTests(unittest.TestCase):
    def make_result(self):
        return {"count": 0, "packages": [], "error": "", "checked": 1}

    def test_parses_update_and_ignored_suffix(self):
        expected = {"name": "foo", "current": "1.0-1", "latest": "1.1-1"}
        self.assertEqual(aur_updates.parse_line("foo 1.0-1 -> 1.1-1"), expected)
        self.assertEqual(
            aur_updates.parse_line("foo 1.0-1 -> 1.1-1 [ignored]"), expected
        )

    def test_unrecognized_output_is_not_a_package(self):
        self.assertIsNone(aur_updates.parse_line("yay: failed to contact AUR"))

    def test_empty_nonzero_result_remains_a_clean_no_updates_result(self):
        proc = subprocess.CompletedProcess(["yay"], 1, "", "")
        result = aur_updates.read_result(proc, self.make_result())
        self.assertEqual(result["count"], 0)
        self.assertEqual(result["error"], "")

    def test_unexpected_empty_failure_status_is_reported(self):
        proc = subprocess.CompletedProcess(["yay"], 2, "", "")
        result = aur_updates.read_result(proc, self.make_result())
        self.assertIn("codice 2", result["error"])

    def test_unrecognized_stdout_becomes_an_error(self):
        proc = subprocess.CompletedProcess(["yay"], 1, "yay: failed to contact AUR\n", "")
        result = aur_updates.read_result(proc, self.make_result())
        self.assertEqual(result["count"], 0)
        self.assertIn("failed to contact AUR", result["error"])

    def test_failed_query_with_valid_partial_output_keeps_packages_and_error(self):
        proc = subprocess.CompletedProcess(
            ["yay"], 2, "foo 1.0-1 -> 1.1-1\n", "network failure\n"
        )
        result = aur_updates.read_result(proc, self.make_result())
        self.assertEqual(result["count"], 1)
        self.assertEqual(result["packages"][0]["name"], "foo")
        self.assertEqual(result["error"], "network failure")


class AurChangelogTests(unittest.TestCase):
    def test_success_cache_uses_six_hour_ttl(self):
        cached = {"fetched": 1000, "value": {"available": True, "error": ""}}
        self.assertTrue(aur_changelog.cache_is_fresh(cached, now=1000 + 5 * 3600))
        self.assertFalse(aur_changelog.cache_is_fresh(cached, now=1000 + 7 * 3600))

    def test_error_cache_uses_short_ttl(self):
        cached = {"fetched": 1000, "value": {"available": False, "error": "offline"}}
        self.assertTrue(aur_changelog.cache_is_fresh(cached, now=1000 + 4 * 60))
        self.assertFalse(aur_changelog.cache_is_fresh(cached, now=1000 + 6 * 60))

    def test_request_timeout_obeys_global_deadline(self):
        with patch.object(aur_changelog.time, "monotonic", return_value=100):
            self.assertEqual(aur_changelog.request_timeout(104), 4)
            with self.assertRaises(TimeoutError):
                aur_changelog.request_timeout(99)

    def test_fresh_cached_entries_skip_network_requests(self):
        cached_value = {"available": True, "repo": "url", "commits": [], "error": ""}
        cache = {
            "foo": {"fetched": aur_changelog.time.time(), "value": cached_value}
        }
        output = io.StringIO()
        with (
            patch.object(sys, "argv", ["aur-changelog", "foo"]),
            patch.object(aur_changelog, "load_cache", return_value=cache),
            patch.object(aur_changelog, "aur_urls") as aur_rpc,
            patch.object(aur_changelog, "save_cache"),
            redirect_stdout(output),
        ):
            aur_changelog.main()
        aur_rpc.assert_not_called()
        self.assertEqual(json.loads(output.getvalue())["foo"], cached_value)

    def test_recognizes_github_and_nested_gitlab_urls(self):
        self.assertEqual(
            aur_changelog.github_repo("https://github.com/example/project.git"),
            ("example", "project"),
        )
        self.assertEqual(
            aur_changelog.gitlab_project(
                "https://gitlab.com/group/subgroup/project/-/tree/main"
            ),
            "group/subgroup/project",
        )


if __name__ == "__main__":
    unittest.main()
