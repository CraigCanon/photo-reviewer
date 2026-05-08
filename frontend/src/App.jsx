import React from "react";
import { useEffect, useMemo, useState } from "react";
import { Auth } from "aws-amplify";
import { Authenticator } from "@aws-amplify/ui-react";
import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";

const PHOTO_STATE_FILTERS = [
  { label: "All states", value: "ALL" },
  { label: "Pending First Review", value: "Pending First Review" },
  { label: "Pending Second Review", value: "Pending Second Review" },
  { label: "Approved to Publish", value: "Approved to Publish" },
  { label: "Rejected", value: "Rejected" },
  { label: "Finalized", value: "Finalized" },
];

const REVIEW_OPTIONS = [
  {
    status: "Good",
    label: "Mark Good",
    loadingLabel: "Submitting...",
    border: "#16a34a",
    background: "#f0fdf4",
    color: "#166534",
  },
  {
    status: "Bad",
    label: "Mark Bad",
    loadingLabel: "Submitting...",
    border: "#dc2626",
    background: "#fef2f2",
    color: "#991b1b",
  },
  {
    status: "Additional Review Required",
    label: "Needs More Review",
    loadingLabel: "Submitting...",
    border: "#a16207",
    background: "#fffbeb",
    color: "#854d0e",
  },
];

function getPhotoId(photo) {
  return photo?.photo_id || photo?.id || "unknown";
}

function getPhotoRotation(photo) {
  const rawRotation = Number(photo?.orientation_degrees || 0);
  return ((rawRotation % 360) + 360) % 360;
}

function ReviewButtons({ photoId, actionLoading, onSubmitReview }) {
  return (
    <div style={{ display: "flex", gap: "0.5rem", flexWrap: "wrap" }}>
      {REVIEW_OPTIONS.map((option) => (
        <button
          key={option.status}
          type="button"
          onClick={() => onSubmitReview(photoId, option.status)}
          disabled={Boolean(actionLoading)}
          style={{
            border: `1px solid ${option.border}`,
            background: option.background,
            color: option.color,
            borderRadius: "8px",
            padding: "0.4rem 0.65rem",
            cursor: actionLoading ? "wait" : "pointer",
          }}
        >
          {actionLoading === `${photoId}:${option.status}` ? option.loadingLabel : option.label}
        </button>
      ))}
    </div>
  );
}

function FullSizePhotoModal({
  photo,
  imageUrl,
  actionLoading,
  rotationLoading,
  onClose,
  onRotate,
  onSubmitReview,
}) {
  if (!photo) {
    return null;
  }

  const photoId = getPhotoId(photo);
  const rotation = getPhotoRotation(photo);

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-labelledby="full-size-photo-title"
      style={{
        position: "fixed",
        inset: 0,
        zIndex: 20,
        background: "rgba(24, 24, 27, 0.76)",
        display: "grid",
        placeItems: "center",
        padding: "1rem",
      }}
      onClick={onClose}
    >
      <section
        style={{
          width: "min(1100px, 100%)",
          maxHeight: "calc(100vh - 2rem)",
          background: "white",
          borderRadius: "10px",
          boxShadow: "0 24px 80px rgba(0, 0, 0, 0.35)",
          display: "grid",
          gridTemplateRows: "auto minmax(0, 1fr) auto",
          overflow: "hidden",
        }}
        onClick={(event) => event.stopPropagation()}
      >
        <header
          style={{
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
            gap: "1rem",
            padding: "0.85rem 1rem",
            borderBottom: "1px solid #e4e4e7",
          }}
        >
          <div>
            <h2 id="full-size-photo-title" style={{ margin: 0, fontSize: "1rem" }}>
              {photoId}
            </h2>
            <div style={{ fontSize: "0.85rem", opacity: 0.75 }}>
              State: {photo.current_state || "Unknown"} | Rotation: {rotation} deg
            </div>
          </div>
          <button
            type="button"
            onClick={onClose}
            style={{
              border: "1px solid #d4d4d8",
              background: "white",
              borderRadius: "8px",
              padding: "0.45rem 0.7rem",
              cursor: "pointer",
            }}
          >
            Close
          </button>
        </header>

        <div
          style={{
            minHeight: "280px",
            background: "#18181b",
            display: "grid",
            placeItems: "center",
            overflow: "hidden",
            padding: "1rem",
          }}
        >
          {imageUrl ? (
            <img
              src={imageUrl}
              alt={photoId}
              style={{
                maxWidth: rotation % 180 === 0 ? "100%" : "calc(100vh - 260px)",
                maxHeight: rotation % 180 === 0 ? "calc(100vh - 260px)" : "100%",
                objectFit: "contain",
                transform: `rotate(${rotation}deg)`,
                transition: "transform 160ms ease",
              }}
            />
          ) : (
            <p style={{ color: "#fafafa" }}>No preview available</p>
          )}
        </div>

        <footer
          style={{
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
            gap: "0.75rem",
            padding: "0.85rem 1rem",
            borderTop: "1px solid #e4e4e7",
            flexWrap: "wrap",
          }}
        >
          <div style={{ display: "flex", gap: "0.5rem", flexWrap: "wrap" }}>
            <button
              type="button"
              onClick={() => onRotate(photoId, "counterclockwise")}
              disabled={Boolean(rotationLoading)}
              style={{
                border: "1px solid #d4d4d8",
                background: "#f8fafc",
                borderRadius: "8px",
                padding: "0.45rem 0.7rem",
                cursor: rotationLoading ? "wait" : "pointer",
              }}
            >
              {rotationLoading === `${photoId}:counterclockwise` ? "Rotating..." : "Rotate Left"}
            </button>
            <button
              type="button"
              onClick={() => onRotate(photoId, "clockwise")}
              disabled={Boolean(rotationLoading)}
              style={{
                border: "1px solid #d4d4d8",
                background: "#f8fafc",
                borderRadius: "8px",
                padding: "0.45rem 0.7rem",
                cursor: rotationLoading ? "wait" : "pointer",
              }}
            >
              {rotationLoading === `${photoId}:clockwise` ? "Rotating..." : "Rotate Right"}
            </button>
          </div>
          <ReviewButtons
            photoId={photoId}
            actionLoading={actionLoading}
            onSubmitReview={(nextPhotoId, status) => onSubmitReview(nextPhotoId, status, true)}
          />
        </footer>
      </section>
    </div>
  );
}

function MissingAuthConfig({ missingAuthEnv }) {
  return (
    <main
      style={{
        minHeight: "100vh",
        display: "grid",
        placeItems: "center",
        fontFamily: "ui-sans-serif, system-ui, -apple-system, sans-serif",
      }}
    >
      <section style={{ textAlign: "center", maxWidth: "36rem", padding: "1rem" }}>
        <h1 style={{ marginBottom: "0.5rem" }}>Photo Scanner</h1>
        <p style={{ margin: 0, opacity: 0.8 }}>
          Authentication is not configured yet. Set these frontend environment variables:
        </p>
        <pre
          style={{
            marginTop: "1rem",
            textAlign: "left",
            background: "#f4f4f5",
            border: "1px solid #e4e4e7",
            borderRadius: "8px",
            padding: "0.75rem",
            overflowX: "auto",
          }}
        >
          {missingAuthEnv.join("\n")}
        </pre>
      </section>
    </main>
  );
}

function MissingApiConfig({ missingApiEnv }) {
  return (
    <main
      style={{
        minHeight: "100vh",
        display: "grid",
        placeItems: "center",
        fontFamily: "ui-sans-serif, system-ui, -apple-system, sans-serif",
      }}
    >
      <section style={{ textAlign: "center", maxWidth: "36rem", padding: "1rem" }}>
        <h1 style={{ marginBottom: "0.5rem" }}>Photo Scanner</h1>
        <p style={{ margin: 0, opacity: 0.8 }}>
          Photo review API is not configured. Set this frontend environment variable:
        </p>
        <pre
          style={{
            marginTop: "1rem",
            textAlign: "left",
            background: "#f4f4f5",
            border: "1px solid #e4e4e7",
            borderRadius: "8px",
            padding: "0.75rem",
            overflowX: "auto",
          }}
        >
          {missingApiEnv.join("\n")}
        </pre>
      </section>
    </main>
  );
}

function PhotoListPage({ apiEndpoint, signOut, user }) {
  const [photos, setPhotos] = useState([]);
  const [photoUrls, setPhotoUrls] = useState({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [actionLoading, setActionLoading] = useState("");
  const [rotationLoading, setRotationLoading] = useState("");
  const [selectedState, setSelectedState] = useState("Pending First Review");
  const [selectedPhotoId, setSelectedPhotoId] = useState("");

  const userLabel = useMemo(
    () => user?.attributes?.email || user?.username || "user",
    [user]
  );

  const fetchPhotoUrls = async (photoItems, token) => {
    const pairs = await Promise.all(
      photoItems.map(async (photo) => {
        const photoId = photo.photo_id || photo.id;
        if (!photoId) {
          return null;
        }

        try {
          const response = await fetch(`${apiEndpoint}/photos/${photoId}/url`, {
            headers: {
              Authorization: `Bearer ${token}`,
            },
          });

          if (!response.ok) {
            return null;
          }

          const data = await response.json();
          if (!data?.url) {
            return null;
          }

          return [photoId, data.url];
        } catch {
          return null;
        }
      })
    );

    return Object.fromEntries(pairs.filter(Boolean));
  };

  const loadPhotos = async (stateOverride) => {
    setLoading(true);
    setError("");
    try {
      const state = stateOverride || selectedState;
      const params = new URLSearchParams();
      if (state !== "ALL") {
        params.set("state", state);
      }

      const photosUrl = params.toString()
        ? `${apiEndpoint}/photos?${params.toString()}`
        : `${apiEndpoint}/photos`;

      const session = await Auth.currentSession();
      const token = session.getIdToken().getJwtToken();
      const response = await fetch(photosUrl, {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      });

      if (!response.ok) {
        throw new Error(`Failed to load photos (${response.status})`);
      }

      const data = await response.json();
      const nextPhotos = Array.isArray(data.photos) ? data.photos : [];
      setPhotos(nextPhotos);
      const nextPhotoUrls = await fetchPhotoUrls(nextPhotos, token);
      setPhotoUrls(nextPhotoUrls);
      return nextPhotos;
    } catch (err) {
      setPhotoUrls({});
      setError(err.message || "Failed to load photos");
      return [];
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadPhotos(selectedState);
  }, [selectedState]);

  const getNextPhotoId = (photoId) => {
    if (photos.length <= 1) {
      return "";
    }

    const currentIndex = photos.findIndex((photo) => getPhotoId(photo) === photoId);
    if (currentIndex === -1) {
      return getPhotoId(photos[0]);
    }

    const nextIndex = currentIndex + 1 < photos.length ? currentIndex + 1 : 0;
    return getPhotoId(photos[nextIndex]);
  };

  const updatePhotoRotation = (photoId, orientationDegrees) => {
    setPhotos((currentPhotos) =>
      currentPhotos.map((photo) =>
        getPhotoId(photo) === photoId
          ? { ...photo, orientation_degrees: orientationDegrees }
          : photo
      )
    );
  };

  const rotatePhoto = async (photoId, direction) => {
    setRotationLoading(`${photoId}:${direction}`);
    setError("");
    try {
      const session = await Auth.currentSession();
      const token = session.getIdToken().getJwtToken();
      const response = await fetch(`${apiEndpoint}/photos/${photoId}/rotate`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ direction }),
      });

      if (!response.ok) {
        const payload = await response.json().catch(() => ({}));
        const message = payload?.message || payload?.error || `Rotation failed (${response.status})`;
        throw new Error(message);
      }

      const payload = await response.json();
      updatePhotoRotation(photoId, payload.orientation_degrees || 0);
    } catch (err) {
      setError(err.message || "Failed to rotate photo");
    } finally {
      setRotationLoading("");
    }
  };

  const submitReview = async (photoId, reviewStatus, advanceAfterSubmit = false) => {
    setActionLoading(`${photoId}:${reviewStatus}`);
    setError("");
    const nextPhotoId = advanceAfterSubmit ? getNextPhotoId(photoId) : "";
    try {
      const session = await Auth.currentSession();
      const token = session.getIdToken().getJwtToken();
      const response = await fetch(`${apiEndpoint}/photos/${photoId}/review`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ review_status: reviewStatus }),
      });

      if (!response.ok) {
        const payload = await response.json().catch(() => ({}));
        const message = payload?.message || payload?.error || `Review failed (${response.status})`;
        throw new Error(message);
      }

      const reloadedPhotos = await loadPhotos();
      if (advanceAfterSubmit) {
        const reloadedNextPhoto = reloadedPhotos.find((photo) => getPhotoId(photo) === nextPhotoId);
        setSelectedPhotoId(
          reloadedNextPhoto ? nextPhotoId : reloadedPhotos[0] ? getPhotoId(reloadedPhotos[0]) : ""
        );
      }
    } catch (err) {
      setError(err.message || "Failed to submit review");
    } finally {
      setActionLoading("");
    }
  };

  const selectedPhoto = useMemo(
    () => photos.find((photo) => getPhotoId(photo) === selectedPhotoId) || null,
    [photos, selectedPhotoId]
  );

  return (
    <main
      style={{
        minHeight: "100vh",
        fontFamily: "ui-sans-serif, system-ui, -apple-system, sans-serif",
        maxWidth: "960px",
        margin: "0 auto",
        padding: "2rem 1rem",
      }}
    >
      <header
        style={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          gap: "1rem",
          marginBottom: "1.5rem",
          flexWrap: "wrap",
        }}
      >
        <div>
          <h1 style={{ margin: 0 }}>Review Photos</h1>
          <p style={{ margin: "0.35rem 0 0", opacity: 0.8 }}>Signed in as {userLabel}</p>
          <div style={{ marginTop: "0.75rem", display: "flex", alignItems: "center", gap: "0.5rem" }}>
            <label htmlFor="photo-state-filter" style={{ fontSize: "0.9rem", fontWeight: 600 }}>
              State:
            </label>
            <select
              id="photo-state-filter"
              value={selectedState}
              onChange={(event) => setSelectedState(event.target.value)}
              style={{
                border: "1px solid #d4d4d8",
                background: "white",
                borderRadius: "8px",
                padding: "0.45rem 0.6rem",
              }}
            >
              {PHOTO_STATE_FILTERS.map((option) => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>
          </div>
        </div>
        <div style={{ display: "flex", gap: "0.5rem" }}>
          <button
            type="button"
            onClick={() => loadPhotos()}
            style={{
              border: "1px solid #d4d4d8",
              background: "white",
              borderRadius: "8px",
              padding: "0.5rem 0.8rem",
              cursor: "pointer",
            }}
          >
            Refresh
          </button>
          <button
            type="button"
            onClick={signOut}
            style={{
              border: "1px solid #d4d4d8",
              background: "white",
              borderRadius: "8px",
              padding: "0.5rem 0.8rem",
              cursor: "pointer",
            }}
          >
            Sign out
          </button>
        </div>
      </header>

      {loading ? <p>Loading photos...</p> : null}
      {!loading && error ? (
        <p style={{ color: "#b91c1c", marginBottom: "1rem" }}>Error: {error}</p>
      ) : null}
      {!loading && !error && photos.length === 0 ? <p>No photos found for review.</p> : null}

      {!loading && !error && photos.length > 0 ? (
        <section style={{ display: "grid", gap: "0.75rem" }}>
          {photos.map((photo) => {
            const photoId = getPhotoId(photo);
            const currentState = photo.current_state || "Unknown";
            const thumbnailUrl = photoUrls[photoId] || "";
            const rotation = getPhotoRotation(photo);
            return (
              <article
                key={photoId}
                style={{
                  border: "1px solid #e4e4e7",
                  borderRadius: "10px",
                  padding: "0.8rem",
                  background: "#fff",
                }}
              >
                <div style={{ display: "flex", gap: "0.8rem", flexWrap: "wrap" }}>
                  <button
                    type="button"
                    onClick={() => setSelectedPhotoId(photoId)}
                    aria-label={`Open full size image for ${photoId}`}
                    style={{
                      width: "120px",
                      height: "120px",
                      borderRadius: "8px",
                      border: "1px solid #e4e4e7",
                      overflow: "hidden",
                      background: "#f4f4f5",
                      display: "grid",
                      placeItems: "center",
                      fontSize: "0.75rem",
                      color: "#52525b",
                      padding: 0,
                      cursor: thumbnailUrl ? "zoom-in" : "default",
                    }}
                  >
                    {thumbnailUrl ? (
                      <img
                        src={thumbnailUrl}
                        alt={photoId}
                        style={{
                          width: "100%",
                          height: "100%",
                          objectFit: "cover",
                          transform: `rotate(${rotation}deg) scale(${rotation % 180 === 0 ? 1 : 1.36})`,
                          transition: "transform 160ms ease",
                        }}
                      />
                    ) : (
                      "No preview"
                    )}
                  </button>

                  <div style={{ flex: "1 1 320px" }}>
                    <div style={{ marginBottom: "0.5rem" }}>
                      <strong>{photoId}</strong>
                      <div style={{ fontSize: "0.9rem", opacity: 0.8 }}>
                        State: {currentState} | Rotation: {rotation} deg
                      </div>
                    </div>
                    <ReviewButtons
                      photoId={photoId}
                      actionLoading={actionLoading}
                      onSubmitReview={submitReview}
                    />
                  </div>
                </div>
              </article>
            );
          })}
        </section>
      ) : null}
      <FullSizePhotoModal
        photo={selectedPhoto}
        imageUrl={selectedPhoto ? photoUrls[getPhotoId(selectedPhoto)] : ""}
        actionLoading={actionLoading}
        rotationLoading={rotationLoading}
        onClose={() => setSelectedPhotoId("")}
        onRotate={rotatePhoto}
        onSubmitReview={submitReview}
      />
    </main>
  );
}

function AuthenticatedApp({ signOut, user, apiEndpoint }) {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Navigate to="/photos" replace />} />
        <Route
          path="/photos"
          element={<PhotoListPage apiEndpoint={apiEndpoint} signOut={signOut} user={user} />}
        />
        <Route path="*" element={<Navigate to="/photos" replace />} />
      </Routes>
    </BrowserRouter>
  );
}

export default function App({
  authConfigured,
  apiEndpoint,
  missingAuthEnv,
  missingApiEnv,
}) {
  if (!authConfigured) {
    return <MissingAuthConfig missingAuthEnv={missingAuthEnv} />;
  }

  if (missingApiEnv.length > 0) {
    return <MissingApiConfig missingApiEnv={missingApiEnv} />;
  }

  return (
    <Authenticator loginMechanisms={["email"]}>
      {({ signOut, user }) => (
        <AuthenticatedApp apiEndpoint={apiEndpoint} signOut={signOut} user={user} />
      )}
    </Authenticator>
  );
}
