"""Guard against false green CI when Godot reports errors with exit code zero."""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import build_windows as pipeline
from promote_release import validate_request


class LogValidation(unittest.TestCase):
    def test_success_requires_all_markers(self):
        pipeline.validate_log('\n'.join(pipeline.MARKERS), 0, pipeline.MARKERS)

    def test_nonzero_exit_fails(self):
        with self.assertRaises(RuntimeError):
            pipeline.validate_log('\n'.join(pipeline.MARKERS), 1, pipeline.MARKERS)

    def test_script_error_even_with_markers_fails(self):
        for error in ('SCRIPT ERROR: failed', 'Assertion failed: wrong lives', 'ERROR: Missing resource'):
            with self.subTest(error=error), self.assertRaises(RuntimeError):
                pipeline.validate_log('\n'.join(pipeline.MARKERS) + '\n' + error, 0, pipeline.MARKERS)

    def test_missing_marker_fails(self):
        with self.assertRaises(RuntimeError):
            pipeline.validate_log('\n'.join(pipeline.MARKERS[:-1]), 0, pipeline.MARKERS)

    def test_echoed_marker_inside_error_does_not_pass(self):
        with self.assertRaises(RuntimeError):
            pipeline.validate_log('not really GAMEPLAY_CHECKS_PASSED', 0, ('GAMEPLAY_CHECKS_PASSED',))

    def test_warning_is_not_an_error(self):
        pipeline.validate_log('WARNING: informational\n' + '\n'.join(pipeline.MARKERS), 0, pipeline.MARKERS)

    def test_known_teardown_after_complete_qa_is_reported(self):
        error = 'ERROR: 4 resources still in use at exit (run with --verbose for details).'
        diagnostics = pipeline.validate_log('\n'.join(pipeline.MARKERS) + '\n' + error, 0, pipeline.MARKERS)
        self.assertEqual(diagnostics, [error])

    def test_teardown_cannot_hide_an_incomplete_test(self):
        error = 'ERROR: 4 resources still in use at exit (run with --verbose for details).'
        with self.assertRaises(RuntimeError):
            pipeline.validate_log(error + '\n' + '\n'.join(pipeline.MARKERS), 0, pipeline.MARKERS)

    def test_teardown_does_not_allow_other_errors(self):
        text = '\n'.join(pipeline.MARKERS) + '\nERROR: 4 resources still in use at exit (run with --verbose for details).\nERROR: Missing media'
        with self.assertRaises(RuntimeError):
            pipeline.validate_log(text, 0, pipeline.MARKERS)

    def test_timeout_fails(self):
        with tempfile.TemporaryDirectory() as temp, patch.object(pipeline, 'OUT', Path(temp)):
            with patch.object(subprocess, 'run', side_effect=subprocess.TimeoutExpired('godot', 1)):
                with self.assertRaisesRegex(RuntimeError, 'timed out'):
                    pipeline.run([sys.executable], 'timeout', timeout=1)

    def test_release_requires_exact_source_and_acceptance(self):
        valid = {'version': 'v1.0.1', 'preview_tag': 'test-123-1-abcdef01',
                 'source_commit': 'a' * 40, 'accepted_by': 'Дмитрий, принятие в чате'}
        validate_request(valid)
        for key in ('version', 'source_commit', 'preview_tag', 'accepted_by'):
            with self.subTest(key=key), self.assertRaises(ValueError):
                validate_request({**valid, key: None})


if __name__ == '__main__':
    unittest.main()
