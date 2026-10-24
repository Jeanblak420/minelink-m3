import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';

/// "Navigation setup" at `/super-admin/navigation-setup`: how to put a mine's
/// own haul roads into the driver's turn-by-turn navigation.
///
/// A read-only guide; the app performs none of it. Added on Jean's go-ahead
/// (2026-10-24) in place of the empty Platform settings page. The oldest `ML`
/// tree had a guide like this and was read as reference only — this one is
/// written for THIS app, and corrects three things that one got wrong here:
///
/// - The setting is `VALHALLA_BASE_URL`. This app asks Valhalla first, with
///   truck costing (`routing_service.dart`), and only falls back to OSRM, so
///   pointing `OSRM_BASE_URL` at a mine-aware server changes nothing.
/// - The Docker image moved from `gis-ops/docker-valhalla` to the Valhalla
///   project's own `ghcr.io/valhalla/valhalla-scripted`.
/// - Truck access is the `hgv` key, which truck costing checks. `truck=yes`
///   is not an OpenStreetMap access key.
///
/// It also adds the step the old guide left out: the haul roads must be
/// joined to the public road at the gate, or no route can reach them. And it
/// ends with a test route, because nothing here has been run end to end
/// against this app — the guide is written from the Valhalla and osmium
/// documentation, and that test is the proof.
class NavigationSetupScreen extends StatelessWidget {
  const NavigationSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MlPageBody(
      maxWidth: 880,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const MlPageHeader(
            title: 'Navigation setup',
            description:
                "How to add a mine's own haul roads to the drivers' "
                'turn-by-turn navigation.',
          ),
          const SizedBox(height: 16),
          const _Notice(
            text: 'These steps are done outside the app, by your GIS or IT '
                'team. The app does not run them and nothing on this page '
                'changes anything.',
          ),
          const SizedBox(height: 16),
          _Card(
            title: 'How navigation finds its roads',
            children: [
              _para(context,
                  "A driver's route comes from a Valhalla routing server, "
                  'asked for a truck route. If it does not answer, the app '
                  'tries OSRM, and if that fails too it shows the direction '
                  'and distance to the destination.'),
              _para(context,
                  'Out of the box the app uses the free public server '
                  '(valhalla1.openstreetmap.de). It only knows public '
                  'OpenStreetMap roads, so inside a mine gate the route stops '
                  'at the nearest public road.'),
              _para(context,
                  "To route on a mine's haul roads, run your own Valhalla "
                  "server with those roads added, and build the app pointed "
                  'at it. Every driver then routes through that server, so it '
                  'must carry all of South Africa, not only the mine.'),
            ],
          ),
          const SizedBox(height: 12),
          _Card(
            step: 1,
            title: 'Prepare the road lines in CAD',
            children: [
              _bullet(context,
                  'Put the road centrelines alone on one layer, for example '
                  'HAUL_ROADS_CENTER.'),
              _bullet(context,
                  'Remove hatching, labels, contours and survey text.'),
              _bullet(context,
                  'Explode blocks so every road is a plain polyline.'),
              _bullet(context,
                  'Note the coordinate system the drawing uses. South '
                  'African mines often use Hartebeesthoek94 / Lo29.'),
              _bullet(context, 'Save as DXF.'),
            ],
          ),
          const SizedBox(height: 12),
          _Card(
            step: 2,
            title: 'Convert it in QGIS',
            children: [
              _bullet(context, 'Add the DXF as a vector layer.'),
              _bullet(context,
                  'Set the layer to the coordinate system noted in step 1.'),
              _bullet(context,
                  'Export it as GeoJSON in EPSG:4326 (WGS 84), the system '
                  'OpenStreetMap uses.'),
            ],
          ),
          const SizedBox(height: 12),
          _Card(
            step: 3,
            title: 'Cut out the area around the mine',
            children: [
              _bullet(context,
                  'Download south-africa-latest.osm.pbf from '
                  'download.geofabrik.de.'),
              _bullet(context,
                  'Cut out a box around the mine (west,south,east,north in '
                  'degrees) and keep this file unchanged; step 5 compares '
                  'against it.'),
              _code(context,
                  'osmium extract -b 29.10,-25.90,29.30,-25.70 \\\n'
                  '  south-africa-latest.osm.pbf -o mine-area.osm'),
            ],
          ),
          const SizedBox(height: 12),
          _Card(
            step: 4,
            title: 'Draw, tag and join the roads in JOSM',
            children: [
              _bullet(context,
                  'Open a copy of mine-area.osm, then open the GeoJSON from '
                  'step 2 (the OpenData plugin reads it) and merge it into '
                  'the same layer.'),
              _bullet(context, 'Tag every haul road:'),
              _tag(context, 'highway', 'service'),
              _tag(context, 'surface', 'unpaved'),
              _tag(context, 'hgv', 'yes'),
              _bullet(context,
                  'Leave access unset. A road tagged access=private may only '
                  'be used at the very start or end of a route.'),
              _bullet(context,
                  'Where two roads cross they must share a node.'),
              _bullet(context,
                  'Join the gate road to the public road outside the gate: '
                  'merge its end node onto a node of the public road. '
                  'Without this the haul roads are an island no route can '
                  'enter.'),
              _bullet(context,
                  'Run the validator, fix what it reports, and save as '
                  'mine-area-edited.osm.'),
            ],
          ),
          const SizedBox(height: 12),
          _Card(
            step: 5,
            title: 'Add the roads to the South Africa map',
            children: [
              _bullet(context,
                  'Turn your edits into a change file, then apply it to the '
                  'full map. Only what you added or changed is carried over.'),
              _code(context,
                  'osmium sort mine-area-edited.osm -o mine-area-edited-sorted.osm\n'
                  'osmium derive-changes mine-area.osm \\\n'
                  '  mine-area-edited-sorted.osm -o mine-roads.osc\n'
                  'osmium apply-changes south-africa-latest.osm.pbf \\\n'
                  '  mine-roads.osc -o south-africa-with-mines.osm.pbf'),
            ],
          ),
          const SizedBox(height: 12),
          _Card(
            step: 6,
            title: 'Run your own Valhalla server',
            children: [
              _bullet(context,
                  'Put south-africa-with-mines.osm.pbf in a folder named '
                  'custom_files and start the server. The first start builds '
                  'the routing tiles, which takes a while.'),
              _code(context,
                  'docker run -dt --name valhalla -p 8002:8002 \\\n'
                  '  -v \$PWD/custom_files:/custom_files \\\n'
                  '  ghcr.io/valhalla/valhalla-scripted:latest'),
              _bullet(context,
                  'Serve it over HTTPS: the web app is refused a plain-HTTP '
                  'server.'),
            ],
          ),
          const SizedBox(height: 12),
          _Card(
            step: 7,
            title: 'Test a route before building the app',
            children: [
              _bullet(context,
                  'Ask your server for a truck route from the public road '
                  'outside the gate to a loading point inside the mine:'),
              _code(context,
                  'curl -X POST https://<your-server>/route -d \'{\n'
                  '  "locations": [\n'
                  '    {"lat": -25.80, "lon": 29.20},\n'
                  '    {"lat": -25.81, "lon": 29.22}],\n'
                  '  "costing": "truck"}\''),
              _bullet(context,
                  'The answer should follow the haul roads. If it stops at '
                  'the gate, step 4 is the place to look: an untagged road, '
                  'a missing hgv=yes, or the gate road not joined.'),
            ],
          ),
          const SizedBox(height: 12),
          _Card(
            step: 8,
            title: 'Build the app pointed at your server',
            children: [
              _bullet(context,
                  'The server is chosen when the app is built, so every '
                  'build you hand out (Android, Windows and web) needs it:'),
              _code(context,
                  'flutter build apk --release \\\n'
                  '  --dart-define=VALHALLA_BASE_URL=https://<your-server>'),
              _bullet(context,
                  'If your server is ever down, drivers still get a route '
                  'from OSRM, on public roads only.'),
            ],
          ),
          const SizedBox(height: 12),
          _Card(
            title: 'When the roads change',
            children: [
              _bullet(context,
                  'Repeat steps 3 to 7 with the new drawing and a fresh South '
                  'Africa download, replace the file in custom_files, and '
                  'restart the server; it rebuilds when the file changes.'),
              _bullet(context,
                  'The app itself does not need rebuilding unless the server '
                  'address changes.'),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

Widget _para(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text,
          style: context.mlText.bodyMedium
              .copyWith(color: MlSemantic.of(context).textBody, height: 1.5)),
    );

Widget _bullet(BuildContext context, String text) {
  final s = MlSemantic.of(context);
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, right: 10),
          child: Container(
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(color: s.accentInk, shape: BoxShape.circle),
          ),
        ),
        Expanded(
          child: Text(text,
              style: context.mlText.bodyMedium
                  .copyWith(color: s.textBody, height: 1.5)),
        ),
      ],
    ),
  );
}

Widget _tag(BuildContext context, String key, String value) {
  final s = MlSemantic.of(context);
  return Padding(
    padding: const EdgeInsets.only(left: 16, bottom: 6),
    child: Text.rich(
      TextSpan(children: [
        TextSpan(text: key, style: context.mlText.code(color: s.accentInk, size: 13)),
        TextSpan(text: '=', style: context.mlText.code(color: s.textMuted, size: 13)),
        TextSpan(text: value, style: context.mlText.code(color: s.textStrong, size: 13)),
      ]),
    ),
  );
}

/// A command, selectable so it can be copied. Long lines scroll sideways
/// inside the block rather than pushing a phone's page wider.
Widget _code(BuildContext context, String code) {
  final s = MlSemantic.of(context);
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: s.surfaceSunken,
      borderRadius: MlShape.radiusMedium,
      border: Border.all(color: s.borderSubtle),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SelectableText(
        code,
        style: context.mlText
            .code(color: s.textStrong, size: 12.5, weight: FontWeight.w500)
            .copyWith(height: 1.5),
      ),
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children, this.step});

  final int? step;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final s = MlSemantic.of(context);
    return MlCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (step != null) ...[
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: MlTokens.accent,
                    borderRadius: MlShape.radiusSmall,
                  ),
                  child: Text('$step',
                      style: context.mlText
                          .code(color: MlTokens.inkOnAccent, size: 13)),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(title,
                    style: context.mlText.titleMedium
                        .copyWith(color: s.textStrong)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = MlTone.warn.colors(Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: MlShape.radiusMedium,
        border: Border.all(color: c.fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 20, color: c.fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: context.mlText.bodyMedium
                    .copyWith(color: c.fg, height: 1.45)),
          ),
        ],
      ),
    );
  }
}
