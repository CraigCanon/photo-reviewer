import React from "react";
import ReactDOM from "react-dom/client";
import { Amplify } from "aws-amplify";
import App from "./App";
import "@aws-amplify/ui-react/styles.css";

const authEnv = {
  userPoolId: import.meta.env.VITE_COGNITO_USER_POOL_ID,
  userPoolWebClientId: import.meta.env.VITE_COGNITO_CLIENT_ID,
  region: import.meta.env.VITE_AWS_REGION,
  apiEndpoint: import.meta.env.VITE_API_ENDPOINT,
};

const missingAuthEnv = Object.entries(authEnv)
  .filter(([key]) => key !== "apiEndpoint")
  .filter(([, value]) => !value)
  .map(([key]) => key);

const missingApiEnv = Object.entries(authEnv)
  .filter(([key]) => key === "apiEndpoint")
  .filter(([, value]) => !value)
  .map(([key]) => key);

const authConfigured = missingAuthEnv.length === 0;

if (authConfigured) {
  Amplify.configure({
    Auth: {
      region: authEnv.region,
      userPoolId: authEnv.userPoolId,
      userPoolWebClientId: authEnv.userPoolWebClientId,
      authenticationFlowType: "USER_PASSWORD_AUTH",
    },
  });
}

ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <App
      authConfigured={authConfigured}
      apiEndpoint={authEnv.apiEndpoint}
      missingAuthEnv={missingAuthEnv}
      missingApiEnv={missingApiEnv}
    />
  </React.StrictMode>
);
