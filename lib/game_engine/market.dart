import 'combat/catalog.dart';
import 'combat/equipment.dart';
import 'rng.dart';

/// Something for sale at a market.
class Offer {
  const Offer(this.cardId, this.price, {this.sold = false});
  final String cardId;
  final int price;
  final bool sold;

  Offer get bought => Offer(cardId, price, sold: true);
}

/// A shop's stock for the current visit.
class Market {
  const Market(
    this.systemId,
    this.offers, {
    this.rerolls = 0,
    this.tradingPost = false,
  });
  final String systemId;
  final List<Offer> offers;

  /// A small shop that only deals in supplies and commodities, with no
  /// shipyard.
  final bool tradingPost;

  /// Rerolls bought this visit. Each costs more than the last.
  final int rerolls;

  static const size = 27;
  static const tradingPostSize = 9;

  int get rerollPrice => 5 * (rerolls + 1);

  /// A market has 27 offers: 18 pieces of equipment and 9 commodities. A
  /// trading post has 9: 4 supplies and 5 commodities. Equipment is mostly
  /// basic, sometimes upgraded, rarely super, priced 0.8–1.2 of its value.
  /// Commodities sell at this shop's going rate. [stock] limits which
  /// equipment families can turn up.
  static Market roll(
    String systemId,
    GameRng rng,
    int galaxySeed, {
    int rerolls = 0,
    bool tradingPost = false,
    List<EquipmentFamily> stock = equipmentFamilies,
    int? time,
  }) {
    final offers = <Offer>[];
    final families = tradingPost
        ? [
            for (final f in stock)
              if (f.kind == CardKind.supplies) f,
          ]
        : stock;
    for (var i = 0; i < (tradingPost ? 4 : 18); i++) {
      final family = rng.pick(families);
      final roll = rng.nextDouble();
      final tier = roll < 0.6 ? 0 : (roll < 0.9 ? 1 : 2);
      final card = family.tiers[tier];
      offers.add(
        Offer(card.id, (card.price * rng.rangeDouble(0.8, 1.2)).round()),
      );
    }
    for (var i = 0; i < (tradingPost ? 5 : 9); i++) {
      final good = rng.weighted(commodities, (g) => g.shopOdds)!;
      offers.add(
        Offer(good.id, commodityPrice(good, systemId, galaxySeed, time: time)),
      );
    }
    return Market(systemId, offers, rerolls: rerolls, tradingPost: tradingPost);
  }

  Market withOffer(int index, Offer offer) => Market(
    systemId,
    [...offers]..[index] = offer,
    rerolls: rerolls,
    tradingPost: tradingPost,
  );

  /// Whether this shop will buy [card]. Trading posts only take supplies
  /// and commodities.
  bool buys(Equipment card) =>
      card.kind != CardKind.mission &&
      (!tradingPost || card.kind != CardKind.equipment);
}

/// A station with too little or too much of a staple for a season. Short
/// of it, the station pays several times its going rate; swimming in it,
/// the station sells it for a fraction, and pays a fraction too.
enum SupplyShock {
  famine('Famine', 'goods_grain', 2.5, 4),
  drought('Drought', 'goods_ice', 2.5, 4),
  harvest('Bumper harvest', 'goods_grain', 0.25, 0.45),
  glut('Ice glut', 'goods_ice', 0.25, 0.45);

  const SupplyShock(this.label, this.goodId, this.low, this.high);
  final String label;
  final String goodId;

  /// The range the going rate is multiplied by.
  final double low;
  final double high;

  bool get shortage => low > 1;
}

/// Supply shocks come and go every this many turns (fights, in a brawl).
const supplySeason = 3;

/// Odds of each kind of shock at a station in a given season.
const supplyOdds = 0.1;

int _hash(int seed, String key) {
  var h = seed;
  for (final c in key.codeUnits) {
    h = (h * 31 + c) & 0x7FFFFFFF;
  }
  return h;
}

/// The supply shock at [systemId] during turn [time], if any. A station
/// has at most one at a time.
SupplyShock? supplyAt(String systemId, int galaxySeed, int time) {
  final season = time ~/ supplySeason;
  final roll = GameRng(
    _hash(galaxySeed ^ 0xF4A1, '$systemId/$season'),
  ).nextDouble();
  final i = (roll / supplyOdds).floor();
  return i < SupplyShock.values.length ? SupplyShock.values[i] : null;
}

/// A commodity's price at a given market. The going rate is 0.6–1.6 of its
/// base value, fixed for the whole run, so some markets are always good
/// places to buy grain and others to sell it. At turn [time], a
/// [SupplyShock] in the good at that station multiplies its going rate.
int commodityPrice(
  Equipment good,
  String systemId,
  int galaxySeed, {
  int? time,
}) {
  final h = _hash(galaxySeed ^ 0x51ED, '$systemId/${good.id}');
  var multiplier = 0.6 + (GameRng(h).nextDouble());
  if (time != null) {
    if (supplyAt(systemId, galaxySeed, time) case final shock?
        when shock.goodId == good.id) {
      final season = time ~/ supplySeason;
      multiplier *= GameRng(h ^ season).rangeDouble(shock.low, shock.high);
    }
  }
  return (good.price * multiplier).round().clamp(1, 1 << 20);
}

/// What a card usually costs across [markets]: the median of their going
/// rates without any supply shocks, so a captain can tell a bargain from a
/// rip-off. Equipment and supplies are offered around their base value
/// everywhere.
int medianPrice(Equipment card, Iterable<String> markets, int galaxySeed) {
  if (card.kind != CardKind.commodity) return card.price;
  final prices = [for (final m in markets) commodityPrice(card, m, galaxySeed)]
    ..sort();
  if (prices.isEmpty) return card.price;
  final mid = prices.length ~/ 2;
  return prices.length.isOdd
      ? prices[mid]
      : ((prices[mid - 1] + prices[mid]) / 2).round();
}

/// What a market pays for a card at turn [time]: half the value of
/// equipment and supplies, the going rate for commodities.
int sellPrice(Equipment card, String systemId, int galaxySeed, {int? time}) =>
    card.kind == CardKind.commodity
    ? commodityPrice(card, systemId, galaxySeed, time: time)
    : card.price ~/ 2;

/// Credits for a permanent +100 hull at a shipyard: 50, 100, 200, 400…
int hullUpgradePrice(int bought) => 50 << bought;

/// Hull repaired per credit at a shipyard.
const hullPerCredit = 5;
