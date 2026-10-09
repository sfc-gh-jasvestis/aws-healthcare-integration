import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from publish_bundles import make_event, upload_request
from setup_aws import ident, names


class SetupAwsTests(unittest.TestCase):
    def test_names_are_scoped_to_prefix_account_region(self):
        n = names('apj-hie', '123456789012', 'us-west-2')
        self.assertEqual(n['bucket'], 'apj-hie-123456789012-us-west-2')
        self.assertEqual(n['storage_int'], 'APJ_HIE_S3_INT')
        self.assertEqual(n['eai'], 'APJ_HIE_BEDROCK_EAI')

    def test_rejects_unsafe_identifiers(self):
        for bad in ['DB; DROP', 'a-b', '1abc', '']:
            with self.assertRaises(ValueError):
                ident(bad)

    def test_upload_request_matches_aws_schema(self):
        import random
        import botocore.session
        from botocore.validate import validate_parameters
        n = names('apj-hie', '123456789012', 'us-west-2')
        rng = random.Random(7)
        req = upload_request(n['bucket'], [make_event(rng) for _ in range(5)], 1700000000000)
        model = botocore.session.get_session().get_service_model('s3')
        validate_parameters(req, model.operation_model('PutObject').input_shape)
        # Objects must land under the prefix the stage, pipe and S3 notification watch.
        self.assertTrue(req['Key'].startswith('bundles/'))
        self.assertEqual(len(req['Body'].decode().strip().splitlines()), 5)

    def test_bundle_event_matches_pipe_columns(self):
        import random
        event = make_event(random.Random(7))
        self.assertEqual(set(event), {'facility_id', 'event_ts', 'latency_min', 'unmapped_code_pct', 'status', 'sent_ms'})
        self.assertRegex(event['facility_id'], r'^FAC-00[0-3]\d$')
        self.assertIn(event['status'], ('ALERT', 'OK'))


if __name__ == '__main__':
    unittest.main()
