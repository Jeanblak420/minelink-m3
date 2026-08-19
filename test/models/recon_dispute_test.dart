import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/portal/models/recon_dispute.dart';

void main() {
  group('DisputeStatus', () {
    test('wire round-trips and parse is tolerant', () {
      for (final s in DisputeStatus.values) {
        expect(DisputeStatus.parse(s.wire), s);
      }
      expect(DisputeStatus.parse('nonsense'), DisputeStatus.open);
      expect(DisputeStatus.parse(null), DisputeStatus.open);
    });

    test('terminal vs active', () {
      expect(DisputeStatus.open.isActive, isTrue);
      expect(DisputeStatus.underReview.isActive, isTrue);
      expect(DisputeStatus.resolved.isTerminal, isTrue);
      expect(DisputeStatus.rejected.isTerminal, isTrue);
      expect(DisputeStatus.withdrawn.isTerminal, isTrue);
    });
  });

  group('DisputeCategory', () {
    test('wire round-trips and parse falls back to other', () {
      for (final c in DisputeCategory.values) {
        expect(DisputeCategory.parse(c.wire), c);
      }
      expect(DisputeCategory.parse('unknown'), DisputeCategory.other);
    });
  });

  test('ReconDispute.fromJson maps list_recon_disputes columns', () {
    final d = ReconDispute.fromJson({
      'id': 'd1',
      'trip_id': 't1',
      'transaction_id': 'txn1',
      'category': 'short_delivery',
      'reason': 'Delivered short by ~2t',
      'claimed_tons': 2.0,
      'status': 'under_review',
      'reference': 'TRP-ABC',
      'truck_reg': 'CA 123-456',
      'source_name': 'Iron Hills Mining',
      'customer_name': 'Atlas Buyer Group',
      'transporter_name': 'Roadhaul Logistics',
      'mine_net_tons': 35.0,
      'delivered_tons': 34.8,
      'variance': 0.2,
      'raised_by_user_id': 'u1',
      'raised_by_name': 'Jane Buyer',
      'raised_by_company_id': 'c1',
      'raised_by_company_name': 'Atlas Buyer Group',
      'resolution': null,
      'resolved_at': null,
      'comment_count': 3,
      'created_at': '2026-07-27T10:00:00Z',
      'updated_at': '2026-07-27T11:00:00Z',
    });

    expect(d.id, 'd1');
    expect(d.tripId, 't1');
    expect(d.category, DisputeCategory.shortDelivery);
    expect(d.status, DisputeStatus.underReview);
    expect(d.status.isActive, isTrue);
    expect(d.variance, closeTo(0.2, 1e-9));
    expect(d.claimedTons, closeTo(2.0, 1e-9));
    expect(d.commentCount, 3);
    expect(d.resolution, isNull);
    expect(d.resolvedAt, isNull);
    expect(d.raisedByName, 'Jane Buyer');
  });

  test('ReconDisputeComment.fromJson maps admin flag + author', () {
    final c = ReconDisputeComment.fromJson({
      'id': 'k1',
      'author_user_id': 'u9',
      'author_name': 'Platform Admin',
      'author_company_id': null,
      'author_company_name': null,
      'author_is_admin': true,
      'body': 'Reviewing the weighbridge ticket now.',
      'created_at': '2026-07-27T12:00:00Z',
    });

    expect(c.authorIsAdmin, isTrue);
    expect(c.authorName, 'Platform Admin');
    expect(c.authorCompanyName, isNull);
    expect(c.body, contains('weighbridge'));
  });
}
