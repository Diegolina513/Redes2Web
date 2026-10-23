import unittest

from app import app


class AppTest(unittest.TestCase):
    def setUp(self):
        self.client = app.test_client()

    def test_home_returns_expected_json(self):
        response = self.client.get('/')
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.is_json)
        self.assertEqual(response.get_json(), {'mensaje': 'Servidor Flask funcionando'})

    def test_unknown_route_is_not_found(self):
        self.assertEqual(self.client.get('/ruta-inexistente').status_code, 404)

    def test_home_rejects_post(self):
        self.assertEqual(self.client.post('/').status_code, 405)
