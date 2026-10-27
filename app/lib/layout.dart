import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Phones and tablets (boards T1, T2): one app, laid out by size. A tablet is a screen whose
/// shorter side is at least [tabletMinWidth] dp, so a phone turned sideways stays a phone.
const double tabletMinWidth = 600;

/// The phone layout's width on a larger screen that isn't a tablet layout. The web build
/// (for testing only) always keeps this column.
const double phoneMaxWidth = 480;

/// On a tablet, list screens are a centred column this wide.
const double tabletBodyWidth = 720;

bool isTablet(BuildContext context) =>
    !kIsWeb && MediaQuery.sizeOf(context).shortestSide >= tabletMinWidth;

/// A tablet held sideways: the Reader shows the page beside the controls (board T2).
bool isTabletLandscape(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return isTablet(context) && size.width > size.height;
}
