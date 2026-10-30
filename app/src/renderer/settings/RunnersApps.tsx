// "More apps from RUNNERS" and "Services from RUNNERS": a gray title over a card per group, one
// row per app with its icon, name, one-line description and a "Get" button (RunnersAppSections).
// The list and icons are the ones the About page ships; Split itself is left out.
import list from "../about/runners-apps.json";
import monitor from "../about/assets/monitor.png";
import prompt from "../about/assets/prompt.png";
import pudding from "../about/assets/pudding.png";
import sense from "../about/assets/sense.png";
import { Button, Card, Row, Section } from "./components.tsx";
import { useStrings } from "./strings.ts";

const ICONS: Record<string, string> = { monitor, prompt, pudding, sense };

type Text = string | { ko?: string; en?: string };

/** The list only has Korean and English text; every other language gets the English line. */
function pick(value: Text, korean: boolean): string {
  if (typeof value === "string") {
    return value;
  }
  return (korean ? value.ko : value.en) || value.en || "";
}

export function RunnersApps({ locale }: { locale: string }) {
  const { t } = useStrings();
  const korean = locale.startsWith("ko");
  const groups = list.groups
    .map((group) => ({ ...group, items: group.items.filter((item) => item.id !== "split" && item.url) }))
    .filter((group) => group.items.length > 0);

  return (
    <>
      {groups.map((group) => (
        <Section key={group.id} title={t(group.id === "services" ? "RunnersServicesTitle" : "RunnersAppsTitle")}>
          <Card>
            {group.items.map((item) => (
              <Row
                key={item.id}
                padding={13}
                title={
                  <span className="runners-app">
                    {ICONS[item.id] ? <img src={ICONS[item.id]} width={32} height={32} alt="" draggable={false} /> : <span className="runners-app-blank" />}
                    <span className="runners-app-text">
                      <span className="runners-app-name">{pick(item.name as Text, korean)}</span>
                      <span className="runners-app-desc">{pick(item.desc as Text, korean)}</span>
                    </span>
                  </span>
                }
              >
                <Button small onClick={() => window.open(item.url, "_blank")}>
                  {t("RunnersGet")}
                </Button>
              </Row>
            ))}
          </Card>
        </Section>
      ))}
    </>
  );
}
