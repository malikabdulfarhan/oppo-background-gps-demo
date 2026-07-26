import 'package:flutter/material.dart';

import '../models/location_record.dart';

class LocationLogList extends StatelessWidget {
  const LocationLogList({required this.records, super.key});

  final List<LocationRecord> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE4E7EC)),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.location_searching_rounded,
              size: 34,
              color: Color(0xFF98A2B3),
            ),
            SizedBox(height: 10),
            Text(
              'No location samples yet',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 4),
            Text(
              'Start tracking to generate simulated GPS records.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF667085), fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      primary: false,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: records.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return _LocationLogItem(
          record: records[index],
          sequence: records.length - index,
        );
      },
    );
  }
}

class _LocationLogItem extends StatelessWidget {
  const _LocationLogItem({required this.record, required this.sequence});

  final LocationRecord record;
  final int sequence;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF4FF),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              '$sequence',
              style: const TextStyle(
                color: Color(0xFF155EEF),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF3),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        record.movementType,
                        style: const TextStyle(
                          color: Color(0xFF027A48),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      record.formattedTimestamp,
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    _Value(
                      label: 'LAT',
                      value: record.latitude.toStringAsFixed(6),
                    ),
                    _Value(
                      label: 'LNG',
                      value: record.longitude.toStringAsFixed(6),
                    ),
                    _Value(
                      label: 'ACC',
                      value: '${record.accuracyMeters.toStringAsFixed(1)} m',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Value extends StatelessWidget {
  const _Value({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: const TextStyle(
              color: Color(0xFF98A2B3),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: Color(0xFF344054),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
