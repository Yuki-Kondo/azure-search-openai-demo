import { Example } from "./Example";

import styles from "./Example.module.css";

export type ExampleModel = {
    text: string;
    value: string;
};

const EXAMPLES: ExampleModel[] = [
    {
        text: "回答できること について教えてください",
        value: "回答できること について教えてください"
    },
    { 
        text: "１．ChatGPTプロンプトの効果的な書き方 について教えてください", 
        value: "１．ChatGPTプロンプトの効果的な書き方 について教えてください" 
    },
    { 
        text: "「文章を要約する」について教えてください", 
        value: "「文章を要約する」について教えてください" 
    }
];

interface Props {
    onExampleClicked: (value: string) => void;
}

export const ExampleList = ({ onExampleClicked }: Props) => {
    return (
        <ul className={styles.examplesNavList}>
            {EXAMPLES.map((x, i) => (
                <li key={i}>
                    <Example text={x.text} value={x.value} onClick={onExampleClicked} />
                </li>
            ))}
        </ul>
    );
};
