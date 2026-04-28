import Link from '@docusaurus/Link';
import Layout from '@theme/Layout';
import useBaseUrl from '@docusaurus/useBaseUrl';
import styles from './index.module.css';

function Feature({title, children}) {
  return (
    <article className={styles.card}>
      <h3>{title}</h3>
      <p>{children}</p>
    </article>
  );
}

export default function Home() {
  const heroImage = useBaseUrl('/img/saveflow/saveflow-product-hero.png');

  return (
    <Layout
      title="Scene-authored save workflows for Godot 4"
      description="SaveFlow Lite helps Godot projects build explicit, inspectable save graphs.">
      <header className="hero hero--saveflow">
        <div className={styles.heroBanner}>
          <div className={styles.heroInner}>
            <div className={styles.heroCopy}>
              <div className={styles.eyebrow}>SaveFlow Lite</div>
              <h1 className={styles.headline}>Build save systems from the scene tree.</h1>
              <p className={styles.summary}>
                SaveFlow Lite organizes Godot save logic into explicit Sources, Scopes,
                slot metadata, runtime entity collections, and C# typed-state helpers.
              </p>
              <div className={styles.actions}>
                <Link className="button button--primary button--lg" to="/docs/getting-started/install">
                  Start with Lite
                </Link>
                <Link className="button button--secondary button--lg" to="/docs/workflows/choose-your-source">
                  Choose a Source
                </Link>
              </div>
            </div>
            <div className={styles.heroVisual} aria-hidden="true">
              <img src={heroImage} alt="" className={styles.heroImage} />
            </div>
          </div>
        </div>
      </header>
      <main>
        <section className={styles.section}>
          <div className="container">
            <div className={styles.grid}>
              <Feature title="Scene-authored">
                Put save ownership where Godot developers can see it: Sources,
                Scopes, factories, and pipeline signal nodes in the scene tree.
              </Feature>
              <Feature title="Typed by default">
                Use typed GDScript data, C# typed state, and slot metadata helpers
                instead of spreading string-key dictionaries across gameplay code.
              </Feature>
              <Feature title="Lite boundary">
                Lite owns the baseline save graph, correctness, diagnostics, and
                practical workflows. Pro will own orchestration, migration, cloud,
                storage profiles, reference repair, and seamless saves.
              </Feature>
            </div>
          </div>
        </section>
      </main>
    </Layout>
  );
}
