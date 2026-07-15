import type { CloudLoadFailure, ContentMode } from '@/lib/cloud/types';



type TenantBootstrapChromeProps = {

  isCloudMode: boolean;

  showTopProgress: boolean;

  contentMode: ContentMode;

  contentFallback: CloudLoadFailure | null;

  onRetry: () => void;

};



export function TenantBootstrapChrome({

  isCloudMode,

  showTopProgress,

  contentMode,

  contentFallback,

  onRetry,

}: TenantBootstrapChromeProps) {

  return (

    <>

      {isCloudMode && showTopProgress ? (

        <>

          <style>

            {`@keyframes jp-top-progress-slide { 0% { transform: translateX(-120%); } 100% { transform: translateX(320%); } }`}

          </style>

          <div

            role="status"

            aria-live="polite"

            aria-label="Cloud loading progress"

            style={{

              position: 'fixed',

              top: 0,

              left: 0,

              right: 0,

              height: 2,

              zIndex: 1300,

              background: 'rgba(255,255,255,0.08)',

              overflow: 'hidden',

            }}

          >

            <div

              style={{

                width: '32%',

                height: '100%',

                background:

                  'linear-gradient(90deg, rgba(88,166,255,0.15) 0%, rgba(88,166,255,0.85) 50%, rgba(88,166,255,0.15) 100%)',

                animation: 'jp-top-progress-slide 1.15s ease-in-out infinite',

                willChange: 'transform',

              }}

            />

          </div>

        </>

      ) : null}

      {isCloudMode && (contentMode === 'error' || contentFallback?.reasonCode === 'CLOUD_REFRESH_FAILED') ? (

        <div

          role="status"

          aria-live="polite"

          style={{

            position: 'fixed',

            top: 12,

            right: 12,

            zIndex: 1200,

            background: 'rgba(179, 65, 24, 0.92)',

            border: '1px solid rgba(255,255,255,0.18)',

            color: '#fff',

            padding: '8px 12px',

            borderRadius: 10,

            fontSize: 12,

            maxWidth: 360,

            boxShadow: '0 8px 24px rgba(0,0,0,0.25)',

          }}

        >

          {contentMode === 'error' ? 'Cloud content unavailable.' : 'Cloud refresh failed, showing cached content.'}

          {contentFallback ? (

            <div style={{ opacity: 0.85, marginTop: 4 }}>

              <div>{contentFallback.message}</div>

              <div style={{ marginTop: 2 }}>

                Reason: {contentFallback.reasonCode}

                {contentFallback.correlationId ? ` | Correlation: ${contentFallback.correlationId}` : ''}

              </div>

              <div style={{ marginTop: 8 }}>

                <button

                  type="button"

                  onClick={onRetry}

                  style={{

                    border: '1px solid rgba(255,255,255,0.3)',

                    borderRadius: 8,

                    padding: '4px 10px',

                    background: 'transparent',

                    color: '#fff',

                    cursor: 'pointer',

                    fontSize: 12,

                  }}

                >

                  Retry

                </button>

              </div>

            </div>

          ) : null}

        </div>

      ) : null}

    </>

  );

}



