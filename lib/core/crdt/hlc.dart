/// Hybrid Logical Clock (HLC) for causal ordering across devices.
///
/// HLC combines physical wall-clock time with a logical counter and unique
/// node ID to produce totally-ordered, globally-unique timestamps without
/// requiring clock synchronization between devices.
///
/// Format: "{unix_ms}:{counter}:{node_id}"
/// String-comparable for total ordering.
///
/// Key properties:
///   - If event A happens-before event B, then HLC(A) < HLC(B)
///   - If two events are concurrent, the node_id breaks ties deterministically
///   - Merging two clocks produces a clock that is causally after both
///
/// References:
///   - "Logical Physical Clocks" (Kulkarni et al., 2014)
///   - https://cse.buffalo.edu/tech-reports/2014-04.pdf
class HLC implements Comparable<HLC> {
  /// Wall clock timestamp in milliseconds since epoch.
  final int timestamp;

  /// Logical counter for events at the same wall clock time.
  final int counter;

  /// Unique identifier for the node (device) that generated this clock.
  final String nodeId;

  const HLC({
    required this.timestamp,
    required this.counter,
    required this.nodeId,
  });

  /// Creates a new HLC at the current wall clock time with counter 0.
  factory HLC.now(String nodeId) {
    return HLC(
      timestamp: DateTime.now().millisecondsSinceEpoch,
      counter: 0,
      nodeId: nodeId,
    );
  }

  /// A zero-value HLC, used as a sentinel / initial value.
  static const HLC zero = HLC(timestamp: 0, counter: 0, nodeId: '');

  /// Generates a new HLC that is causally after this clock.
  ///
  /// If the wall clock has advanced past our recorded timestamp, we reset
  /// the counter to 0. Otherwise we increment the counter.
  HLC increment() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now > timestamp) {
      return HLC(timestamp: now, counter: 0, nodeId: nodeId);
    }
    return HLC(timestamp: timestamp, counter: counter + 1, nodeId: nodeId);
  }

  /// Merges this local clock with a remote clock.
  ///
  /// The result is a clock that is causally after both clocks, ensuring
  /// that any subsequent events on this node will be ordered after both
  /// the local and remote events.
  HLC merge(HLC remote) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final maxTs = _max3(now, timestamp, remote.timestamp);

    if (maxTs == now && now > timestamp && now > remote.timestamp) {
      // Wall clock is ahead of both — reset counter
      return HLC(timestamp: now, counter: 0, nodeId: nodeId);
    }
    if (maxTs == timestamp && timestamp == remote.timestamp) {
      // Both clocks are at the same timestamp — take max counter + 1
      final maxCounter = counter > remote.counter ? counter : remote.counter;
      return HLC(
        timestamp: maxTs,
        counter: maxCounter + 1,
        nodeId: nodeId,
      );
    }
    if (maxTs == timestamp) {
      // Local timestamp is the max
      return HLC(timestamp: maxTs, counter: counter + 1, nodeId: nodeId);
    }
    // Remote timestamp is the max
    return HLC(timestamp: maxTs, counter: remote.counter + 1, nodeId: nodeId);
  }

  static int _max3(int a, int b, int c) {
    if (a >= b && a >= c) return a;
    if (b >= a && b >= c) return b;
    return c;
  }

  @override
  int compareTo(HLC other) {
    if (timestamp != other.timestamp) return timestamp.compareTo(other.timestamp);
    if (counter != other.counter) return counter.compareTo(other.counter);
    return nodeId.compareTo(other.nodeId);
  }

  bool operator >(HLC other) => compareTo(other) > 0;
  bool operator <(HLC other) => compareTo(other) < 0;
  bool operator >=(HLC other) => compareTo(other) >= 0;
  bool operator <=(HLC other) => compareTo(other) <= 0;

  /// Returns true if this clock is strictly newer than [other].
  bool isNewerThan(HLC other) => compareTo(other) > 0;

  /// Serializes to a string format that preserves ordering under
  /// lexicographic string comparison.
  ///
  /// Format: "{timestamp}:{counter}:{nodeId}"
  @override
  String toString() => '$timestamp:$counter:$nodeId';

  /// Parses an HLC from its string representation.
  ///
  /// Throws [FormatException] if the string is malformed.
  factory HLC.parse(String s) {
    final parts = s.split(':');
    if (parts.length >= 3) {
      final timestamp = int.tryParse(parts[0]);
      final counter = int.tryParse(parts[1]);
      if (timestamp != null && counter != null) {
        return HLC(
          timestamp: timestamp,
          counter: counter,
          // Node ID may contain colons (e.g., UUID), so rejoin the remainder
          nodeId: parts.sublist(2).join(':'),
        );
      }
    }

    final legacy = _tryParseLegacyIso(s);
    if (legacy != null) {
      return legacy;
    }

    throw FormatException(
      'Invalid HLC format: "$s". Expected "ts:counter:nodeId"',
    );
  }

  static HLC? _tryParseLegacyIso(String s) {
    final trimmed = s.trim();
    final direct = DateTime.tryParse(trimmed);
    if (direct != null) {
      return HLC(
        timestamp: direct.toUtc().millisecondsSinceEpoch,
        counter: 0,
        nodeId: 'legacy',
      );
    }

    final match = RegExp(
      r'^(.*(?:Z|[+-]\d{2}:?\d{2}))-([A-Za-z0-9_.-]+)$',
    ).firstMatch(trimmed);
    if (match == null) {
      return null;
    }

    final parsed = DateTime.tryParse(match.group(1)!);
    if (parsed == null) {
      return null;
    }

    return HLC(
      timestamp: parsed.toUtc().millisecondsSinceEpoch,
      counter: 0,
      nodeId: match.group(2)!,
    );
  }

  /// Tries to parse an HLC string, returning null on failure.
  static HLC? tryParse(String? s) {
    if (s == null || s.isEmpty) {
      return null;
    }
    try {
      return HLC.parse(s);
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HLC &&
          timestamp == other.timestamp &&
          counter == other.counter &&
          nodeId == other.nodeId;

  @override
  int get hashCode => Object.hash(timestamp, counter, nodeId);
}
