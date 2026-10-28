import 'package:flutter/material.dart';

/// Style « espace » (maquette validée par Paul le 28/10/2026) : toujours
/// sombre, futuriste, deux couleurs seulement, translucides : l'orange
/// (la to-do, ce qui reste à faire, la moins bonne réponse) et le vert
/// d'eau (aujourd'hui, ce qui est fait, la meilleure réponse) ; le reste
/// en blanc et gris. Une seule police partout, Oxanium (anguleuse,
/// futuriste ; choix de Paul du 28/10/2026), embarquée en 4 graisses,
/// licence OFL (`assets/fonts/OFL-Oxanium.txt`). Les noms policeTitre,
/// policeTexte, policeMono et policeRetro restent pour s'y retrouver.
class AppTheme {
  static const policeTitre = 'Oxanium';

  /// Les deux couleurs de l'appli.
  static const orange = Color(0xFFFF8A2A);
  static const vertDeau = Color(0xFF34E0B0);

  /// Couleur de la seconde courbe quand on en compare deux (lilas, bien
  /// distinct du citron et du corail).
  static const courbeB = Color(0xFFA594FF);
  static const policeTexte = 'Oxanium';

  /// Écran rétro du compte rendu et chiffres : Oxanium aussi (28/10/2026).
  static const policeRetro = 'Oxanium';
  static const policeMono = 'Oxanium';

  /// Couleurs des deux toi : ambre le soir, bleu-vert le jour.
  /// L'orange d'Orbite (les deux noms servent encore dans le code).
  static const ambre = Color(0xFFFF8A2A);
  static const bleuVert = Color(0xFFFF8A2A);

  /// Orange translucide : fonds de ce qui est choisi ou prévu.
  static const orangeVoile = Color(0x38FF8A2A);

  /// Un seul style partout (Paul, 27/10/2026).
  static ThemeData sombre() => _theme(Teintes.orbite, Brightness.dark);
  static ThemeData soir() => _theme(Teintes.orbite, Brightness.dark);
  static ThemeData jour() => _theme(Teintes.orbite, Brightness.dark);

  /// Vieux terminal bleu-vert sur noir : le compte rendu de fin de
  /// journée.
  static ThemeData retro() => _theme(
    Teintes.retro,
    Brightness.dark,
    texte: policeMono,
    titre: policeRetro,
    tailleTitre: 1.4,
  );

  static ThemeData _theme(
    Teintes t,
    Brightness luminosite, {
    String texte = policeTexte,
    String titre = policeTitre,
    double tailleTitre = 1,
  }) {
    final policeTexte = texte;
    final policeTitre = titre;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: t.accent,
          brightness: luminosite,
        ).copyWith(
          primary: t.texte,
          onPrimary: t.fond,
          secondary: t.accent,
          onSecondary: t.surAccent,
          surface: t.fond,
          onSurface: t.texte,
          onSurfaceVariant: t.doux,
          outline: t.doux,
          outlineVariant: t.trait,
          surfaceContainerLowest: t.carte,
          surfaceContainerLow: t.carte,
          surfaceContainer: t.carte,
          surfaceContainerHigh: t.carte,
          surfaceContainerHighest: t.puce,
          secondaryContainer: t.accent,
          onSecondaryContainer: t.surAccent,
          error: luminosite == Brightness.dark
              ? const Color(0xFFFF8A80)
              : const Color(0xFFC0392B),
        );
    final base = ThemeData(brightness: luminosite).textTheme;
    final styles = base
        .apply(
          fontFamily: policeTexte,
          bodyColor: t.texte,
          displayColor: t.texte,
        )
        .copyWith(
          titleLarge: TextStyle(
            fontFamily: policeTitre,
            fontSize: 20 * tailleTitre,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: t.texte,
          ),
          titleMedium: TextStyle(
            fontFamily: policeTexte,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: t.texte,
          ),
          bodyLarge: TextStyle(
            fontFamily: policeTexte,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: t.texte,
          ),
          bodyMedium: TextStyle(
            fontFamily: policeTexte,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: t.texte,
          ),
        );
    final pilule = t.forme;
    return ThemeData(
      colorScheme: scheme,
      extensions: [t],
      fontFamily: policeTexte,
      textTheme: styles,
      scaffoldBackgroundColor: t.fond,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: t.fond,
        foregroundColor: t.texte,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: policeTitre,
          fontSize: 20 * tailleTitre,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: t.texte,
        ),
      ),
      cardTheme: CardThemeData(
        color: t.carte,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.rayon + 6),
        ),
      ),
      dividerTheme: DividerThemeData(color: t.trait, space: 1, thickness: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 56),
          shape: pilule,
          backgroundColor: t.texte,
          foregroundColor: t.fond,
          textStyle: TextStyle(
            fontFamily: policeTexte,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 56),
          shape: pilule,
          foregroundColor: t.texte,
          backgroundColor: t.carte,
          side: BorderSide.none,
          textStyle: TextStyle(
            fontFamily: policeTexte,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.texte,
          shape: pilule,
          textStyle: TextStyle(
            fontFamily: policeTexte,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: t.carte,
          selectedBackgroundColor: t.texte,
          selectedForegroundColor: t.fond,
          foregroundColor: t.texte,
          side: BorderSide.none,
          shape: pilule,
          minimumSize: const Size(0, 48),
          textStyle: TextStyle(
            fontFamily: policeTexte,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: t.accent,
        foregroundColor: t.surAccent,
        elevation: 0,
        highlightElevation: 0,
        shape: pilule,
        extendedTextStyle: TextStyle(
          fontFamily: policeTexte,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.carte,
        // Champs serrés : les formulaires tiennent sur un écran.
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(t.rayon),
          borderSide: BorderSide.none,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: pilule,
        side: BorderSide.none,
        backgroundColor: t.puce,
        selectedColor: t.accent,
        labelStyle: WidgetStateTextStyle.resolveWith(
          (etats) => TextStyle(
            fontFamily: policeTexte,
            fontWeight: FontWeight.w700,
            color: etats.contains(WidgetState.selected) ? t.surAccent : t.texte,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.carte,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        titleTextStyle: TextStyle(
          fontFamily: policeTitre,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: t.texte,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.carte,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: t.carte,
        actionTextColor: t.accent,
        contentTextStyle: TextStyle(
          fontFamily: policeTexte,
          fontWeight: FontWeight.w600,
          color: t.texte,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.rayon + 2),
          side: BorderSide(color: t.accent.withValues(alpha: 0.7)),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: t.carte,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      ),
    );
  }

  /// Couleur d'une réponse : citron pour la meilleure, corail pour la
  /// moins bonne, abricot au milieu (3 réponses).
  static Color couleurReponse(BuildContext context, int choix, int nb) {
    final t = Teintes.de(context);
    final rang = nb == 2 && choix == 1 ? 2 : choix;
    return switch (rang) {
      0 => t.meilleure,
      1 => t.moyenne,
      _ => t.moinsBonne,
    };
  }

  /// Texte sur la couleur d'une réponse : toujours foncé (couleurs vives
  /// et claires).
  static Color texteSurReponse(BuildContext context, int choix, int nb) =>
      const Color(0xFF111114);

  /// Le thème d'une page, à l'accent de son onglet.
  static ThemeData avecAccent(ThemeData theme, Color couleur) {
    final t = theme.extension<Teintes>() ?? Teintes.orbite;
    return theme.copyWith(
      extensions: [t.avecAccent(couleur)],
      colorScheme: theme.colorScheme.copyWith(
        secondary: couleur,
        secondaryContainer: couleur,
      ),
      floatingActionButtonTheme: theme.floatingActionButtonTheme.copyWith(
        backgroundColor: couleur,
      ),
    );
  }
}

/// Les couleurs du style.
class Teintes extends ThemeExtension<Teintes> {
  final Color fond;
  final Color carte;

  /// Fond d'une réponse non choisie, des pastilles.
  final Color puce;
  final Color texte;
  final Color doux;
  final Color trait;

  /// Citron : onglet choisi, bouton Ajouter.
  final Color accent;
  final Color surAccent;

  /// Barre d'onglets flottante.
  final Color barre;
  final Color texteBarre;
  final Color meilleure;
  final Color moyenne;
  final Color moinsBonne;

  /// Écran rétro (le compte rendu).
  final bool estRetro;

  /// L'Exécutant (revu le 26/10/2026) : boutons carrés, étiquettes et
  /// heures en police de terminal, texte courant normal.
  final bool terminal;

  /// Arrondi des boutons et des champs : doux (14) partout, presque
  /// carré (3) pour l'Exécutant. Paul trouvait les pilules trop rondes.
  final double rayon;

  const Teintes({
    required this.fond,
    required this.carte,
    required this.puce,
    required this.texte,
    required this.doux,
    required this.trait,
    required this.accent,
    required this.surAccent,
    required this.barre,
    required this.texteBarre,
    required this.meilleure,
    required this.moyenne,
    required this.moinsBonne,
    this.estRetro = false,
    this.terminal = false,
    this.rayon = 14,
  });

  /// Arrondi des petites pastilles (réponses données, séries).
  double get rayonPetit => terminal ? 3 : 8;

  /// La forme des boutons.
  OutlinedBorder get forme =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(rayon));

  /// Le style « espace » : noir profond, blanc cassé, gris ; l'accent
  /// change selon l'onglet (orange ou vert d'eau, [avecAccent]).
  static const orbite = Teintes(
    fond: Color(0xFF05070A),
    carte: Color(0xFF0A0D12),
    puce: Color(0xFF14171C),
    texte: Color(0xFFE8E4DA),
    doux: Color(0xFF8C9099),
    trait: Color(0xFF1B1F26),
    accent: AppTheme.orange,
    surAccent: Color(0xFF05070A),
    barre: Color(0xFF2A2E36),
    texteBarre: Color(0xFFA9ADB5),
    meilleure: AppTheme.vertDeau,
    moyenne: Color(0xFFC7C2B8),
    moinsBonne: AppTheme.orange,
    rayon: 4,
  );

  /// Les mêmes teintes, avec un autre accent (le vert d'eau
  /// d'Aujourd'hui).
  Teintes avecAccent(Color couleur) => Teintes(
    fond: fond,
    carte: carte,
    puce: puce,
    texte: texte,
    doux: doux,
    trait: trait,
    accent: couleur,
    surAccent: surAccent,
    barre: barre,
    texteBarre: texteBarre,
    meilleure: meilleure,
    moyenne: moyenne,
    moinsBonne: moinsBonne,
    estRetro: estRetro,
    terminal: terminal,
    rayon: rayon,
  );

  static const sombre = Teintes(
    fond: Color(0xFF0F0F12),
    carte: Color(0xFF1A1A1F),
    puce: Color(0xFF26262C),
    texte: Color(0xFFF5F5F2),
    doux: Color(0xFFA3A3AD),
    trait: Color(0xFF26262C),
    accent: Color(0xFFD4FF3A),
    surAccent: Color(0xFF0F0F12),
    barre: Color(0xFF2E2E36),
    texteBarre: Color(0xFFC4C4CC),
    meilleure: Color(0xFFD4FF3A),
    moyenne: Color(0xFFFFB547),
    moinsBonne: Color(0xFFFF6B5E),
  );

  /// Le soir : accent ambre (celui qui décide).
  static const soir = Teintes(
    fond: Color(0xFF0F0F12),
    carte: Color(0xFF1A1A1F),
    puce: Color(0xFF26262C),
    texte: Color(0xFFF5F5F2),
    doux: Color(0xFFA3A3AD),
    trait: Color(0xFF26262C),
    accent: AppTheme.ambre,
    surAccent: Color(0xFF0F0F12),
    barre: Color(0xFF2E2E36),
    texteBarre: Color(0xFFC4C4CC),
    meilleure: Color(0xFFD4FF3A),
    moyenne: Color(0xFFFFB547),
    moinsBonne: Color(0xFFFF6B5E),
  );

  /// Le jour, celui qui exécute : terminal sobre, noir bleuté, accent
  /// bleu-vert (maquette validée par Paul le 26/10/2026).
  static const jour = Teintes(
    fond: Color(0xFF07090A),
    carte: Color(0xFF0D1312),
    puce: Color(0xFF1D2B29),
    texte: Color(0xFFE4EFEC),
    doux: Color(0xFF7FA39C),
    trait: Color(0xFF1D2B29),
    accent: AppTheme.bleuVert,
    surAccent: Color(0xFF07090A),
    barre: Color(0xFF0D1312),
    texteBarre: Color(0xFF7FA39C),
    meilleure: Color(0xFFD4FF3A),
    moyenne: Color(0xFFFFB547),
    moinsBonne: Color(0xFFFF7A6B),
    terminal: true,
    rayon: 3,
  );

  /// Le compte rendu : vieux terminal, bleu-vert phosphore sur noir (celui qui
  /// exécute). Réponses : bleu-vert, sable, corail.
  static const retro = Teintes(
    fond: Color(0xFF050807),
    carte: Color(0xFF0B1412),
    puce: Color(0xFF12302B),
    texte: AppTheme.bleuVert,
    doux: Color(0xFF3FA593),
    trait: Color(0xFF12302B),
    accent: AppTheme.bleuVert,
    surAccent: Color(0xFF050807),
    barre: Color(0xFF0B1412),
    texteBarre: Color(0xFF3FA593),
    meilleure: AppTheme.bleuVert,
    moyenne: Color(0xFFE8D7B0),
    moinsBonne: Color(0xFFFF7A6B),
    estRetro: true,
    rayon: 0,
  );

  static Teintes de(BuildContext context) =>
      Theme.of(context).extension<Teintes>() ?? orbite;

  @override
  Teintes copyWith() => this;

  @override
  Teintes lerp(Teintes? autre, double t) => t < 0.5 ? this : (autre ?? this);
}
