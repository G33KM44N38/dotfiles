import { Form, ActionPanel, Action } from "@raycast/api";
import { useState } from "react";

export default function Command() {
  const [todoName, settodoName] = useState<string>("");
  return (
    <Form
      actions={
        <ActionPanel>
          <Action.Open title="Open Database" target={"raycast://extensions/notion/notion/search-page"} />
        </ActionPanel>
      }
    >
      <Form.TextField id="name" title="Enter The Todo name" value={todoName} onChange={settodoName} />
    </Form>
  );
}
