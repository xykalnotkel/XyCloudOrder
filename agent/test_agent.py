import contextlib
import io
import unittest
import urllib.error
from unittest.mock import MagicMock, patch

import xy_agent as agent


class SunshineTests(unittest.TestCase):
    def setUp(self):
        self.sunshine = agent.Sunshine(agent.SUNSHINE_BAWAAN, 'test-user', 'test-password')

    def check(self, reply):
        with patch.object(agent, 'minta', return_value=reply):
            return self.sunshine.periksa()

    def test_401_not_misreported_as_closed_port(self):
        r = self.check({'_galat': 'HTTP 401', '_http_status': 401, '_isi': 'private-body'})
        self.assertEqual(r['status'], 'LOGIN_DITOLAK')
        self.assertFalse(r['siap'])
        self.assertNotIn('private-body', str(r))
        self.assertNotIn('test-password', str(r))

    def test_403_and_404_are_distinguished(self):
        self.assertEqual(self.check({'_galat': 'HTTP 403', '_http_status': 403})['status'], 'LOGIN_DITOLAK')
        self.assertEqual(self.check({'_galat': 'HTTP 404', '_http_status': 404})['status'], 'API_TIDAK_DITEMUKAN')

    def test_connection_refused(self):
        r = self.check({'_galat': '[WinError 10061] Connection refused', '_jenis_galat': 'ConnectionRefusedError'})
        self.assertEqual(r['status'], 'PORT_TERTUTUP')
        self.assertFalse(r['siap'])

    def test_timeout(self):
        r = self.check({'_galat': 'timed out', '_jenis_galat': 'TimeoutError'})
        self.assertEqual(r['status'], 'WAKTU_HABIS')

    def test_html_login_page_is_not_ready(self):
        r = self.check({'teks': '<html>login</html>', '_http_status': 200})
        self.assertEqual(r['status'], 'API_TIDAK_SESUAI')
        self.assertFalse(r['siap'])

    def test_valid_apps_response(self):
        r = self.check({'apps': [], 'env': {}, '_http_status': 200})
        self.assertTrue(r['siap'])
        self.assertEqual(r['status'], 'API_SIAP')

    def test_http_status_preserved_and_local_proxy_bypassed(self):
        error = urllib.error.HTTPError('https://127.0.0.1:47990/api/apps', 401, 'Unauthorized', {}, io.BytesIO(b'{}'))
        opener = MagicMock()
        opener.open.side_effect = error
        with patch.object(agent.urllib.request, 'build_opener', return_value=opener), patch.object(agent.urllib.request, 'ProxyHandler') as proxy:
            result = agent.minta('https://127.0.0.1:47990/api/apps', ssl_longgar=True)
            self.assertEqual(result['_http_status'], 401)
            proxy.assert_called_once_with({})

    def test_diagnostic_mode_never_heartbeats_or_cleans_sessions(self):
        for ready in (False, True):
            with patch.object(agent.sys, 'argv', ['xy_agent.py', '--cek']), patch.dict(agent.os.environ, {}, clear=True), \
                    patch.object(agent.Sunshine, 'periksa', return_value={'siap': ready, 'status': 'test', 'pesan': 'test'}), \
                    patch.object(agent.Agen, 'jalan') as run, patch.object(agent, 'ip_publik') as ip, \
                    patch.object(agent, 'bersihkan_sesi') as cleanup, contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(agent.main(), 0 if ready else 1)
                run.assert_not_called()
                ip.assert_not_called()
                cleanup.assert_not_called()

    def test_not_ready_does_not_close_host_apps(self):
        sunshine = MagicMock()
        sunshine.periksa.return_value = {'siap': False, 'pesan': 'Login ditolak'}
        host = agent.Agen('https://example.invalid', 'local-test-only', sunshine, None)
        with patch.object(agent, 'bersihkan_sesi') as cleanup, patch.object(host, 'balas') as report, contextlib.redirect_stdout(io.StringIO()):
            host.kerjakan({'id': 'test-command', 'jenis': 'mulai_sesi', 'muatan': {'sesi_id': 'test-session'}})
            cleanup.assert_not_called()
            sunshine.hapus_perangkat.assert_not_called()
            self.assertFalse(report.call_args.args[1]['ok'])

    def test_heartbeat_success_is_visible_but_not_spammed(self):
        sunshine = MagicMock()
        sunshine.periksa.return_value = {'siap': True, 'status': 'API_SIAP', 'pesan': 'Ready'}
        host = agent.Agen('https://example.invalid', 'local-test-only', sunshine, None)
        output = io.StringIO()
        with patch.object(agent, 'minta', return_value={'data': {'ok': True, 'perintah': []}}), \
                patch.object(agent, 'spesifikasi', return_value={}), contextlib.redirect_stdout(output):
            host.lapor()
            host.lapor()
        self.assertEqual(output.getvalue().count('HEARTBEAT DITERIMA'), 1)
        self.assertNotIn('local-test-only', output.getvalue())


if __name__ == '__main__':
    unittest.main()
