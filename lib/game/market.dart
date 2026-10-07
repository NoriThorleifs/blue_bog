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
  /// Commodities sell at this shop's going rate.
  static Market roll(
    String systemId,
    GameRng rng,
    int galaxySeed, {
    int rerolls = 0,
    bool tradingPost = false,
  }) {
    final offers = <Offer>[];
    final families = tradingPost
        ? [
            for (final f in equipmentFamilies)
              if (f.kind == CardKind.supplies) f,
          ]
        : equipmentFamilies;
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
      final good = rng.pick(commodities);
      offers.add(Offer(good.id, commodityPrice(good, systemId, galaxySeed)));
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

/// A commodity's price at a given market: 0.6–1.6 of its base value, fixed
/// for the whole run, so some markets are always good places to buy grain
/// and others to sell it.
int commodityPrice(Equipment good, String systemId, int galaxySeed) {
  var h = galaxySeed ^ 0x51ED;
  for (final c in '$systemId/${good.id}'.codeUnits) {
    h = (h * 31 + c) & 0x7FFFFFFF;
  }
  final multiplier = 0.6 + (GameRng(h).nextDouble());
  return (good.price * multiplier).round().clamp(1, 1 << 20);
}

/// What a market pays for a card: half the value of equipment and
/// supplies, the going rate for commodities.
int sellPrice(Equipment card, String systemId, int galaxySeed) =>
    card.kind == CardKind.commodity
    ? commodityPrice(card, systemId, galaxySeed)
    : card.price ~/ 2;

/// Credits for a permanent +100 hull at a shipyard: 50, 100, 200, 400…
int hullUpgradePrice(int bought) => 50 << bought;

/// Hull repaired per credit at a shipyard.
const hullPerCredit = 5;
