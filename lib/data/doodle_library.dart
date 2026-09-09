import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A single line-art reference the doodle canvas can display, trace, or explain.
/// Ported 1:1 from mindspace's `doodle-library.ts` (`RAW_DOODLES`).
class DoodleReference {
  final int id;
  final String title;
  final String category; // Nature | Zen | Cozy | Celestial | Creatures
  final String difficulty; // Easy | Relaxed | Mindful
  final String tagline;
  final List<String> instructions;
  final String svgBody; // inner SVG markup, strokes use `currentColor`
  final String viewBox;

  const DoodleReference({
    required this.id,
    required this.title,
    required this.category,
    required this.difficulty,
    required this.tagline,
    required this.instructions,
    required this.svgBody,
    this.viewBox = '0 0 100 100',
  });

  String _svg() =>
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="$viewBox">$svgBody</svg>';

  /// Renders the reference as tint-able line art.
  Widget toPicture({required Color color, BoxFit fit = BoxFit.contain}) {
    return SvgPicture.string(
      _svg(),
      fit: fit,
      theme: SvgTheme(currentColor: color),
    );
  }
}

/// The five references surfaced on the canvas picker — a short calming break,
/// not a full doodle app (mindspace's `FEATURED_DOODLE_IDS`).
const List<int> kFeaturedDoodleIds = [1, 2, 3, 4, 12];

List<DoodleReference> get featuredDoodles =>
    kDoodleReferences.where((d) => kFeaturedDoodleIds.contains(d.id)).toList();

DoodleReference doodleById(int id) =>
    kDoodleReferences.firstWhere((d) => d.id == id, orElse: () => kDoodleReferences.first);

const List<DoodleReference> kDoodleReferences = [
  DoodleReference(
    id: 1,
    title: 'Lotus Bloom',
    category: 'Nature',
    difficulty: 'Easy',
    tagline: 'A symbol of rebirth and calm emerging from still waters.',
    instructions: [
      'Draw a teardrop shape in the center.',
      'Add curved petals on both left and right sides.',
      'Layer 3 larger outer petals beneath them.',
      'Add gentle rippling water lines at the base.',
    ],
    svgBody: '''
      <path d="M50 25 C42 40 42 60 50 75 C58 60 58 40 50 25 Z" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"/>
      <path d="M47 38 C32 45 28 62 43 73" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"/>
      <path d="M53 38 C68 45 72 62 57 73" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"/>
      <path d="M40 50 C22 56 20 72 38 77" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/>
      <path d="M60 50 C78 56 80 72 62 77" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/>
      <path d="M20 83 C35 81 65 81 80 83" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
      <path d="M28 88 C42 86 58 86 72 88" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
    ''',
  ),
  DoodleReference(
    id: 2,
    title: 'Mountain Sunrise',
    category: 'Nature',
    difficulty: 'Easy',
    tagline: 'Majestic peaks bathed in quiet morning light.',
    instructions: [
      'Draw two overlapping sharp triangular peaks.',
      'Add a ridge line down the center of each mountain.',
      'Draw a soft rising semicircle sun between the peaks.',
      'Add 4 warm radiating sunbeam strokes.',
    ],
    svgBody: '''
      <circle cx="50" cy="45" r="14" fill="none" stroke="currentColor" stroke-width="2" stroke-dasharray="2 3"/>
      <path d="M50 22 L50 16 M32 30 L27 26 M68 30 L73 26" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
      <path d="M15 80 L42 35 L65 72 L78 52 L92 80 Z" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>
      <path d="M42 35 L48 80 M78 52 L74 80" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
      <path d="M10 80 L90 80" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
    ''',
  ),
  DoodleReference(
    id: 3,
    title: 'Zen Mandala Spiral',
    category: 'Zen',
    difficulty: 'Mindful',
    tagline: 'Continuous soothing loops that steady nervous energy.',
    instructions: [
      'Start from a center dot and spiral outwards.',
      'Add 8 petal loops around the perimeter.',
      'Dot the tips of each outer loop.',
      'Repeat with a larger enclosing circle.',
    ],
    svgBody: '''
      <circle cx="50" cy="50" r="6" fill="none" stroke="currentColor" stroke-width="2"/>
      <circle cx="50" cy="50" r="16" fill="none" stroke="currentColor" stroke-width="2" stroke-dasharray="3 3"/>
      <circle cx="50" cy="50" r="34" fill="none" stroke="currentColor" stroke-width="2"/>
      <path d="M50 16 C45 28 55 28 50 16 M50 84 C45 72 55 72 50 84 M16 50 C28 45 28 55 16 50 M84 50 C72 45 72 55 84 50" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
      <path d="M26 26 C36 34 40 28 26 26 M74 74 C64 66 60 72 74 74 M74 26 C66 36 72 40 74 26 M26 74 C34 64 28 60 26 74" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
      <circle cx="50" cy="12" r="2" fill="currentColor"/>
      <circle cx="50" cy="88" r="2" fill="currentColor"/>
      <circle cx="12" cy="50" r="2" fill="currentColor"/>
      <circle cx="88" cy="50" r="2" fill="currentColor"/>
    ''',
  ),
  DoodleReference(
    id: 4,
    title: 'Curled Kitten Nap',
    category: 'Creatures',
    difficulty: 'Easy',
    tagline: 'Peaceful contentment in a tight furry ball.',
    instructions: [
      'Draw a soft circular outline leaving the top slightly open.',
      'Add two triangle ears on top of the head.',
      'Draw two peaceful curved closed-eye lines (^ ^).',
      'Wrap a curved tail around the paws.',
    ],
    svgBody: '''
      <path d="M55 75 C30 75 22 55 35 38 C42 30 58 28 68 35 C78 42 82 58 75 70 C70 78 60 82 48 82 C32 82 20 70 20 52" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"/>
      <path d="M40 32 L36 22 L46 27 M58 27 L66 20 L64 30" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>
      <path d="M43 42 C45 40 48 40 50 42 M56 42 C58 40 61 40 63 42" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
      <path d="M53 47 L53 50 M51 50 L55 50" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
      <path d="M38 48 L28 46 M38 52 L26 53 M66 48 L76 46 M66 52 L78 53" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
    ''',
  ),
  DoodleReference(
    id: 5,
    title: 'Steaming Matcha Cup',
    category: 'Cozy',
    difficulty: 'Easy',
    tagline: 'A warm ceramic mug radiating mindful warmth.',
    instructions: [
      'Draw an open cylinder for the mug body.',
      'Add a cozy loop handle on the right.',
      'Draw two swirling wisps of aromatic steam rising above.',
      'Sketch a tiny heart or leaf on the mug front.',
    ],
    svgBody: '''
      <ellipse cx="50" cy="42" rx="22" ry="7" fill="none" stroke="currentColor" stroke-width="2.5"/>
      <path d="M28 42 L32 75 C34 82 66 82 68 75 L72 42" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"/>
      <path d="M70 48 C80 48 83 66 68 68" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"/>
      <path d="M43 32 C40 26 46 22 43 16 M52 30 C49 24 55 20 52 14 M60 32 C57 26 63 22 60 16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
      <path d="M47 58 C47 55 50 53 52 56 C54 53 57 55 57 58 C57 62 52 66 52 66 C52 66 47 62 47 58 Z" fill="currentColor" opacity="0.8"/>
    ''',
  ),
  DoodleReference(
    id: 6,
    title: 'Monstera Palm Leaf',
    category: 'Nature',
    difficulty: 'Relaxed',
    tagline: 'Lush tropical foliage bringing fresh oxygen to the mind.',
    instructions: [
      'Draw a central curved spine stem.',
      'Create heart-shaped outer leaf lobes.',
      'Cut deep organic notches into each side.',
      'Add gentle inner vein ribs.',
    ],
    svgBody: '''
      <path d="M50 18 C50 18 25 28 24 48 C23 64 36 78 50 82 C64 78 77 64 76 48 C75 28 50 18 50 18 Z" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"/>
      <path d="M50 18 L50 92" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"/>
      <path d="M50 35 C40 34 32 38 25 36 M50 48 C38 48 30 54 24 55 M50 62 C40 64 34 72 30 74" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
      <path d="M50 35 C60 34 68 38 75 36 M50 48 C62 48 70 54 76 55 M50 62 C60 64 66 72 70 74" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
    ''',
  ),
  DoodleReference(
    id: 7,
    title: 'Cosmic Saturn & Rings',
    category: 'Celestial',
    difficulty: 'Easy',
    tagline: 'Infinite cosmic perspective above daily noise.',
    instructions: [
      'Draw a smooth central sphere planet.',
      'Slice an elongated tilted oval ring across the equator.',
      'Erase the hidden rear part of the ring.',
      'Sprinkle 4 tiny four-point stars in the galaxy around it.',
    ],
    svgBody: '''
      <circle cx="50" cy="50" r="20" fill="none" stroke="currentColor" stroke-width="2.5"/>
      <path d="M15 56 C22 42 78 35 85 46 C92 57 28 68 15 56 Z" fill="none" stroke="currentColor" stroke-width="2.5"/>
      <path d="M22 22 L22 28 M19 25 L25 25" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
      <path d="M78 72 L78 78 M75 75 L81 75" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
      <circle cx="80" cy="24" r="1.5" fill="currentColor"/>
      <circle cx="20" cy="76" r="1.5" fill="currentColor"/>
    ''',
  ),
  DoodleReference(
    id: 8,
    title: 'Origami Peace Crane',
    category: 'Zen',
    difficulty: 'Relaxed',
    tagline: 'Geometric folding art representing healing and hope.',
    instructions: [
      'Draw a center diamond for the crane body.',
      'Extend upward angled wings on both sides.',
      'Add a slender folded neck and pointed head.',
      'Draw the sharp tail feather angled down.',
    ],
    svgBody: '''
      <path d="M50 65 L20 30 L45 55 L50 65 Z" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linejoin="round"/>
      <path d="M50 65 L80 30 L55 55 L50 65 Z" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linejoin="round"/>
      <path d="M45 55 L25 50 L18 56" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>
      <path d="M55 55 L78 68" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/>
      <path d="M45 55 L50 82 L55 55" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/>
    ''',
  ),
  DoodleReference(
    id: 9,
    title: 'Floating Sky Lantern',
    category: 'Celestial',
    difficulty: 'Easy',
    tagline: 'Releasing your worries into the peaceful night sky.',
    instructions: [
      'Draw an arched dome lantern frame.',
      'Add straight tapered vertical side lines.',
      'Draw the glowing wooden base rim with a tiny flame.',
      'Add faint rising ember dots around it.',
    ],
    svgBody: '''
      <path d="M35 75 C30 50 30 35 50 25 C70 35 70 50 65 75 Z" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"/>
      <ellipse cx="50" cy="75" rx="15" ry="4" fill="none" stroke="currentColor" stroke-width="2.5"/>
      <circle cx="50" cy="65" r="3" fill="currentColor"/>
      <path d="M50 58 L50 54 M44 60 L40 58 M56 60 L60 58" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
      <circle cx="30" cy="20" r="1.5" fill="currentColor" opacity="0.6"/>
      <circle cx="70" cy="18" r="2" fill="currentColor" opacity="0.6"/>
      <circle cx="78" cy="35" r="1.2" fill="currentColor" opacity="0.4"/>
    ''',
  ),
  DoodleReference(
    id: 10,
    title: 'Bonsai Zen Tree',
    category: 'Nature',
    difficulty: 'Mindful',
    tagline: 'Patience, grounding roots, and deliberate balance.',
    instructions: [
      'Draw a wide shallow ceramic planting dish.',
      'Sketch a gnarled, twisting trunk leaning gracefully.',
      'Add 3 cloud-like leafy foliage pads.',
      'Detail bark lines along the trunk.',
    ],
    svgBody: '''
      <path d="M25 80 L75 80 L70 88 L30 88 Z" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linejoin="round"/>
      <path d="M48 80 C46 65 56 60 52 50 C48 42 42 40 40 32" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round"/>
      <path d="M52 52 C58 50 68 52 70 45" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/>
      <path d="M30 32 C30 25 48 22 52 30 C55 35 45 38 30 32 Z" fill="none" stroke="currentColor" stroke-width="2.2"/>
      <path d="M60 45 C60 40 76 38 78 44 C80 48 70 50 60 45 Z" fill="none" stroke="currentColor" stroke-width="2.2"/>
      <path d="M22 45 C22 40 36 38 38 44 C40 48 30 50 22 45 Z" fill="none" stroke="currentColor" stroke-width="2.2"/>
    ''',
  ),
  DoodleReference(
    id: 11,
    title: 'Evergreen Pine Sprig',
    category: 'Nature',
    difficulty: 'Easy',
    tagline: 'Fresh mountain pine scent that clears the sinuses.',
    instructions: [
      'Draw a gentle curved branch stem.',
      'Add pairs of pine needles branching off at 45 degrees.',
      'Hang a small textured pinecone from the fork.',
      'Keep the strokes crisp and rhythmic.',
    ],
    svgBody: '''
      <path d="M20 80 Q50 60 80 20" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"/>
      <path d="M40 68 L28 62 M40 68 L32 75 M52 55 L40 46 M52 55 L42 60 M65 40 L52 32 M65 40 L56 44 M75 26 L66 18 M75 26 L70 28" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
      <path d="M40 68 L50 60 M52 55 L64 48 M65 40 L76 34" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
    ''',
  ),
  DoodleReference(
    id: 12,
    title: 'Cozy Forest Cabin',
    category: 'Cozy',
    difficulty: 'Relaxed',
    tagline: 'A warm sanctuary of refuge amidst quiet trees.',
    instructions: [
      'Draw a triangle roof with an offset chimney.',
      'Add the rectangular cabin front and a friendly door.',
      'Draw a glowing window with four panes.',
      'Add smoke curling peacefully out of the chimney.',
    ],
    svgBody: '''
      <path d="M25 55 L50 30 L75 55 Z" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linejoin="round"/>
      <path d="M30 55 L30 85 L70 85 L70 55" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"/>
      <path d="M44 85 L44 65 L56 65 L56 85" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
      <rect x="62" y="36" width="6" height="12" fill="none" stroke="currentColor" stroke-width="2"/>
      <path d="M65 32 C62 26 68 22 65 16 C62 12 66 8 64 4" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
      <path d="M15 85 L85 85" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
    ''',
  ),
  DoodleReference(
    id: 13,
    title: 'Whimsical Forest Mushroom',
    category: 'Nature',
    difficulty: 'Easy',
    tagline: 'Earthy grounding in quiet damp moss.',
    instructions: [
      'Draw a wide rounded dome mushroom cap.',
      'Add a thick, slightly curved stalk underneath.',
      'Scatter 4-5 playful polka dots on the cap.',
      'Add tiny blades of grass at the foot.',
    ],
    svgBody: '''
      <path d="M20 55 C20 30 80 30 80 55 C80 58 20 58 20 55 Z" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"/>
      <path d="M38 58 C38 72 36 82 50 82 C64 82 62 72 62 58" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"/>
      <circle cx="36" cy="42" r="3.5" fill="none" stroke="currentColor" stroke-width="1.8"/>
      <circle cx="52" cy="35" r="4.5" fill="none" stroke="currentColor" stroke-width="1.8"/>
      <circle cx="65" cy="45" r="3" fill="none" stroke="currentColor" stroke-width="1.8"/>
      <path d="M30 84 L33 78 M48 84 L50 76 M66 84 L64 78" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
    ''',
  ),
  DoodleReference(
    id: 14,
    title: 'Paper Plane in Flight',
    category: 'Cozy',
    difficulty: 'Easy',
    tagline: 'Lightness, simplicity, and releasing control.',
    instructions: [
      'Draw a sharp triangle pointing up and right.',
      'Fold the center spine crease downwards.',
      'Add a dashed looping trail behind the tail.',
      'Feel the lightness of an unobstructed breeze.',
    ],
    svgBody: '''
      <path d="M85 20 L25 55 L45 62 L85 20 Z" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linejoin="round"/>
      <path d="M85 20 L45 62 L55 75 L62 60" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linejoin="round"/>
      <path d="M15 78 C25 85 30 75 22 68 C15 62 25 55 35 58" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-dasharray="3 4"/>
    ''',
  ),
  DoodleReference(
    id: 15,
    title: 'Night Owl Perch',
    category: 'Creatures',
    difficulty: 'Relaxed',
    tagline: 'Quiet wisdom and calm stillness in the dark.',
    instructions: [
      'Draw a rounded egg-like body on a branch.',
      'Draw two large curious concentric circle eyes.',
      'Add a small downward triangle beak in between.',
      'Tuck folded wing arches on the sides.',
    ],
    svgBody: '''
      <path d="M35 30 C35 24 40 22 45 28 C50 25 55 25 60 28 C65 22 70 24 70 30 C70 50 68 75 52 75 C36 75 35 50 35 30 Z" fill="none" stroke="currentColor" stroke-width="2.5"/>
      <circle cx="44" cy="38" r="6" fill="none" stroke="currentColor" stroke-width="2"/>
      <circle cx="44" cy="38" r="2" fill="currentColor"/>
      <circle cx="60" cy="38" r="6" fill="none" stroke="currentColor" stroke-width="2"/>
      <circle cx="60" cy="38" r="2" fill="currentColor"/>
      <path d="M52 44 L49 48 L55 48 Z" fill="currentColor"/>
      <path d="M15 78 L85 78" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round"/>
    ''',
  ),
  DoodleReference(
    id: 16,
    title: 'Ocean Cresting Wave',
    category: 'Zen',
    difficulty: 'Mindful',
    tagline: 'Allowing emotional surges to rise, crest, and dissolve.',
    instructions: [
      'Draw a sweeping upward curve that curls forward at the top.',
      'Add trailing spray droplets from the crest.',
      'Layer two gentle foam ripples at the base.',
      'Follow the water rhythm without forcing it.',
    ],
    svgBody: '''
      <path d="M10 75 C30 75 40 70 55 52 C65 38 72 25 62 25 C52 25 55 38 48 42" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"/>
      <path d="M10 82 C35 82 50 78 70 65 C85 55 90 48 85 45" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
      <circle cx="68" cy="22" r="1.5" fill="currentColor"/>
      <circle cx="76" cy="28" r="1.5" fill="currentColor"/>
      <circle cx="60" cy="18" r="1.2" fill="currentColor"/>
    ''',
  ),
  DoodleReference(
    id: 17,
    title: 'Lavender Bouquet Sprigs',
    category: 'Nature',
    difficulty: 'Easy',
    tagline: 'Aromatherapy lines that naturally soothe racing pulses.',
    instructions: [
      'Draw 3 slender tall stems crossing at the base.',
      'Add small stacked grain-like buds along the upper stems.',
      'Tie a gentle ribbon bow around the lower stems.',
      'Keep your strokes light and relaxed.',
    ],
    svgBody: '''
      <path d="M40 85 L48 20 M50 85 L52 22 M60 85 L56 25" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
      <ellipse cx="48" cy="25" rx="3" ry="2" fill="currentColor"/>
      <ellipse cx="48" cy="32" rx="3.5" ry="2" fill="currentColor"/>
      <ellipse cx="48" cy="39" rx="4" ry="2.2" fill="currentColor"/>
      <ellipse cx="52" cy="28" rx="3" ry="2" fill="currentColor"/>
      <ellipse cx="52" cy="35" rx="3.5" ry="2" fill="currentColor"/>
      <ellipse cx="56" cy="32" rx="3" ry="2" fill="currentColor"/>
      <ellipse cx="56" cy="39" rx="3.5" ry="2" fill="currentColor"/>
      <path d="M45 68 C40 65 40 72 45 70 C55 65 55 72 50 70" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
    ''',
  ),
  DoodleReference(
    id: 18,
    title: 'Crescent Moon & Constellation',
    category: 'Celestial',
    difficulty: 'Easy',
    tagline: 'Gentle night skies holding space for deep rest.',
    instructions: [
      'Draw an outer smooth circle arc for the moon.',
      'Draw an inner tighter arc connecting the two tips.',
      'Add 3 sparkling cross stars beside the crescent.',
      'Notice the silence between the stars.',
    ],
    svgBody: '''
      <path d="M50 18 C30 18 20 40 28 65 C36 90 68 85 75 75 C55 75 42 60 45 42 C47 28 55 22 50 18 Z" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linejoin="round"/>
      <path d="M68 28 L68 36 M64 32 L72 32" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
      <path d="M78 48 L78 54 M75 51 L81 51" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
      <circle cx="62" cy="62" r="1.5" fill="currentColor"/>
      <circle cx="75" cy="20" r="1.2" fill="currentColor"/>
    ''',
  ),
  DoodleReference(
    id: 19,
    title: 'Potted Jade Succulent',
    category: 'Nature',
    difficulty: 'Relaxed',
    tagline: 'Resilience and storing nourishment through dry seasons.',
    instructions: [
      'Draw a geometric ceramic plant pot.',
      'Layer thick rounded teardrop fleshy leaves from the center.',
      'Add subtle line creases down each plump leaf.',
      'Ground the pot with a clean base shadow.',
    ],
    svgBody: '''
      <path d="M32 60 L68 60 L62 88 L38 88 Z" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linejoin="round"/>
      <path d="M50 32 C45 42 45 52 50 58 C55 52 55 42 50 32 Z" fill="none" stroke="currentColor" stroke-width="2.2"/>
      <path d="M38 42 C42 48 45 54 48 58 C38 56 34 48 38 42 Z" fill="none" stroke="currentColor" stroke-width="2"/>
      <path d="M62 42 C58 48 55 54 52 58 C62 56 66 48 62 42 Z" fill="none" stroke="currentColor" stroke-width="2"/>
      <path d="M28 88 L72 88" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
    ''',
  ),
  DoodleReference(
    id: 20,
    title: 'Singing Songbird on Twig',
    category: 'Creatures',
    difficulty: 'Relaxed',
    tagline: 'A reminder that every dawn brings a fresh song.',
    instructions: [
      'Draw a teardrop body with a round perched head.',
      'Add a sharp open beak and tiny bright eye.',
      'Draw the wing fold along the back and tail feathers.',
      'Perch the feet on a leaf-bud twig.',
    ],
    svgBody: '''
      <path d="M32 45 C32 35 42 30 52 35 C62 40 68 55 58 68 C48 72 38 68 32 45 Z" fill="none" stroke="currentColor" stroke-width="2.5"/>
      <path d="M32 38 L22 36 L30 43 Z" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/>
      <circle cx="40" cy="38" r="2" fill="currentColor"/>
      <path d="M58 68 L78 80 L68 65" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linejoin="round"/>
      <path d="M15 75 Q50 70 85 72" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"/>
      <path d="M42 69 L42 74 M48 69 L48 74" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
    ''',
  ),
  DoodleReference(
    id: 21,
    title: 'Clay Teapot with Spout',
    category: 'Cozy',
    difficulty: 'Easy',
    tagline: 'Pouring out excess thoughts to make room for clarity.',
    instructions: [
      'Draw a rounded teapot belly with a flat base.',
      'Add a graceful curved pouring spout on the left.',
      'Add a round arch handle on the right and lid knob.',
      'Draw steam curling from the spout tip.',
    ],
    svgBody: '''
      <path d="M35 45 C28 55 28 72 38 78 L62 78 C72 72 72 55 65 45 Z" fill="none" stroke="currentColor" stroke-width="2.5"/>
      <path d="M40 45 L60 45 L58 40 L42 40 Z" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/>
      <circle cx="50" cy="37" r="2.5" fill="currentColor"/>
      <path d="M32 58 C22 55 20 48 18 45 L18 52 C20 60 28 66 34 68" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linejoin="round"/>
      <path d="M68 50 C78 50 82 66 68 70" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/>
      <path d="M16 40 C14 34 18 30 16 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
    ''',
  ),
  DoodleReference(
    id: 22,
    title: 'Spiral Nautilus Shell',
    category: 'Zen',
    difficulty: 'Mindful',
    tagline: 'Sacred golden ratio geometry found in nature.',
    instructions: [
      'Start with a tight center spiral.',
      'Expand the logarithmic spiral outward in chambers.',
      'Add subtle radial ribs across the shell chambers.',
      'Reflect on the infinite unfolding of life.',
    ],
    svgBody: '''
      <path d="M50 50 A4 4 0 0 1 54 54 A8 8 0 0 1 46 62 A14 14 0 0 1 32 48 A22 22 0 0 1 54 26 A32 32 0 0 1 86 58 A42 42 0 0 1 44 92 C24 92 12 70 18 44" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/>
      <path d="M50 50 L54 54 M46 62 L42 66 M32 48 L26 46 M54 26 L56 20 M86 58 L92 62" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
    ''',
  ),
  DoodleReference(
    id: 23,
    title: 'Ginkgo Biloba Fan Leaf',
    category: 'Nature',
    difficulty: 'Easy',
    tagline: 'Ancient tree of endurance, hope, and peace of mind.',
    instructions: [
      'Draw a slender stem that arches gracefully.',
      'Draw a wide scalloped fan leaf split lightly in the center notch.',
      'Radiate fine delicate veins from the stem to the ruffled edge.',
      'Breathe gently with every vein drawn.',
    ],
    svgBody: '''
      <path d="M50 85 Q50 68 50 55" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"/>
      <path d="M50 55 C35 52 20 42 22 28 C28 22 45 28 50 35 C55 28 72 22 78 28 C80 42 65 52 50 55 Z" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linejoin="round"/>
      <path d="M50 55 L32 30 M50 55 L42 28 M50 55 L50 35 M50 55 L58 28 M50 55 L68 30" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
    ''',
  ),
];
