// General tab: the options card, the Desktops (Spaces) card, Accessibility permission, the About
// line and the other RUNNERS apps — in the order of -makeGeneralView.
import { useState } from "react";
import type { ViewState } from "../../../shared/types.ts";
import type { Update } from "../App.tsx";
import {
  Alert,
  AppIcon,
  Button,
  Card,
  Row,
  Section,
  Segmented,
  Switch,
} from "../components.tsx";
import { displayShortcut, shortcutFor } from "../keys.ts";
import { RunnersApps } from "../RunnersApps.tsx";
import { useStrings } from "../strings.ts";

// Card 544 wide (600 − 2 × 28); text wraps in what is left after the padding and the control.
const CARD_WIDTH = 544;
const TEXT_WIDTH = CARD_WIDTH - 32 - 70;
const GAP_TEXT_WIDTH = CARD_WIDTH - 32 - 230;
const SPACES_TEXT_WIDTH = CARD_WIDTH - 32 - 90;

const GAPS = [
  { value: 0, label: "GapNone" },
  { value: 8, label: "GapNarrow" },
  { value: 16, label: "GapNormal" },
  { value: 24, label: "GapWide" },
];

const GITHUB_URL = "https://github.com/RUNNERS-IM/split";

/** Shortcuts another app holds and apps that turn Split away, so "nothing happens" has a reason. */
function useProblems(state: ViewState): string[] {
  const { t, f } = useStrings();
  const problems: string[] = [];
  if (state.failures.length > 0) {
    const list = state.failures.map((action) =>
      `${displayShortcut(shortcutFor(state, action), state.platform)} ${t(action)}`.trim(),
    );
    problems.push(f("ShortcutsNotRegistered", list.join(", ")));
  }
  if (state.trusted && state.refusingApp) {
    problems.push(f("ApplicationRefusedAccess", state.refusingApp));
  }
  return problems;
}

export default function GeneralTab({
  state,
  update,
}: {
  state: ViewState;
  update: Update;
}) {
  const { t, f } = useStrings();
  const { settings } = state;
  const [confirmHide, setConfirmHide] = useState(false);
  const problems = useProblems(state);
  const mac = state.platform === "darwin";

  const gap = GAPS.some((g) => g.value === settings.gap) ? settings.gap : 8;

  return (
    <main className="content scroll">
      <Section title={t("SectionBehavior")}>
        <Card>
          <Row
            title={t("LaunchAtLogin")}
            hint={t("LaunchAtLoginHint")}
            textWidth={TEXT_WIDTH}
          >
            <Switch
              label={t("LaunchAtLogin")}
              checked={settings.launchAtLogin}
              onChange={(launchAtLogin) =>
                update((s) => ({ ...s, launchAtLogin }))
              }
            />
          </Row>
          <Row
            title={t("ShowMenuBarIcon")}
            hint={t("ShowMenuBarIconHint")}
            textWidth={TEXT_WIDTH}
          >
            <Switch
              label={t("ShowMenuBarIcon")}
              checked={settings.showTrayIcon}
              onChange={(showTrayIcon) =>
                showTrayIcon
                  ? update((s) => ({ ...s, showTrayIcon }))
                  : setConfirmHide(true)
              }
            />
          </Row>
          <Row
            title={t("WindowGap")}
            hint={t("WindowGapHint")}
            textWidth={GAP_TEXT_WIDTH}
          >
            <Segmented
              label={t("WindowGap")}
              value={gap}
              options={GAPS.map((g) => ({ value: g.value, label: t(g.label) }))}
              onChange={(value) => update((s) => ({ ...s, gap: value }))}
            />
          </Row>
          <Row
            title={t("DisplayChange")}
            hint={t("DisplayChangeHint")}
            textWidth={TEXT_WIDTH}
          >
            <Switch
              label={t("DisplayChange")}
              checked={settings.rearrangeOnDisplayChange}
              onChange={(rearrangeOnDisplayChange) =>
                update((s) => ({ ...s, rearrangeOnDisplayChange }))
              }
            />
          </Row>
          <Row
            title={t("ShortcutSheetHold")}
            hint={t("ShortcutSheetHoldHint")}
            textWidth={TEXT_WIDTH}
          >
            <Switch
              label={t("ShortcutSheetHold")}
              checked={settings.shortcutSheet}
              onChange={(shortcutSheet) =>
                update((s) => ({ ...s, shortcutSheet }))
              }
            />
          </Row>
          {!state.store && (
            <Row
              title={t("AutoUpdate")}
              hint={t("AutoUpdateHint")}
              textWidth={TEXT_WIDTH}
            >
              <Switch
                label={t("AutoUpdate")}
                checked={settings.autoUpdate}
                onChange={(autoUpdate) => update((s) => ({ ...s, autoUpdate }))}
              />
            </Row>
          )}
        </Card>
      </Section>

      {/* Split cannot move windows between desktops, so it points to the macOS settings instead, only while they are on. */}
      {state.spaces && (state.spaces.reorders || state.spaces.separate) && (
        <Section title={t("SpacesSection")}>
          <Card>
            {state.spaces.reorders && (
              <Row
                title={t("SpacesReorder")}
                hint={t("SpacesReorderHint")}
                textWidth={SPACES_TEXT_WIDTH}
              >
                <Button small onClick={() => window.split.openLink("spaces")}>
                  {t("PermissionOpen")}
                </Button>
              </Row>
            )}
            {state.spaces.separate && (
              <Row
                title={t("SpacesSeparate")}
                hint={t("SpacesSeparateHint")}
                textWidth={SPACES_TEXT_WIDTH}
              >
                <Button small onClick={() => window.split.openLink("spaces")}>
                  {t("PermissionOpen")}
                </Button>
              </Row>
            )}
          </Card>
        </Section>
      )}

      {mac ? (
        <Section title={t("SectionPermission")}>
          <Card>
            <Row
              title={t("PermissionTitle")}
              hint={
                <>
                  <span className="permission">
                    <span
                      className={
                        state.trusted ? "permission-dot on" : "permission-dot"
                      }
                      aria-hidden
                    />
                    {t(
                      state.trusted ? "PermissionOnHint" : "PermissionOffHint",
                    )}
                  </span>
                  {problems.length > 0 && (
                    <span className="problems">{problems.join("\n")}</span>
                  )}
                </>
              }
              textWidth={TEXT_WIDTH}
            >
              {!state.trusted && (
                <Button
                  small
                  onClick={() => window.split.openLink("accessibility")}
                >
                  {t("PermissionOpen")}
                </Button>
              )}
            </Row>
          </Card>
        </Section>
      ) : (
        problems.length > 0 && (
          <Section title={t("SectionStatus")}>
            <Card>
              <Row
                title={<span className="problems">{problems.join("\n")}</span>}
              />
            </Card>
          </Section>
        )
      )}

      <Section title={t("SectionAbout")}>
        <Card>
          <div className="about-line">
            <AppIcon size={40} />
            <div className="about-text">
              <div className="about-name">Split</div>
              <div className="about-version">
                {f("AboutLine", state.version)}
              </div>
            </div>
            <div className="row-space" />
            <Button small onClick={() => window.split.openLink("website")}>
              {t("Website")}
            </Button>
            <Button small onClick={() => window.open(GITHUB_URL, "_blank")}>
              GitHub
            </Button>
          </div>
        </Card>
      </Section>

      <RunnersApps locale={state.locale} />

      {confirmHide && (
        <Alert
          message={t("AlertMessageTextRunningInBackground")}
          informative={t("AlertInformativeTextRunningInBackground")}
          confirmLabel={t("ButtonLabelAffirmative")}
          cancelLabel={t("ButtonLabelNegative")}
          onCancel={() => setConfirmHide(false)}
          onConfirm={() => {
            setConfirmHide(false);
            void update((s) => ({ ...s, showTrayIcon: false }));
          }}
        />
      )}
    </main>
  );
}
