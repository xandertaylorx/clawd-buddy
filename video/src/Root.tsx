import {Composition} from 'remotion';
import {Promo, DURATION} from './Promo';
import {Promo169, DURATION169} from './Promo169';
export const Root = () => (
  <>
  <Composition id="Promo169" component={Promo169} durationInFrames={DURATION169} fps={30} width={1920} height={1080} />
  <Composition id="Promo" component={Promo} durationInFrames={DURATION} fps={30} width={1080} height={1920} />
  </>
);
