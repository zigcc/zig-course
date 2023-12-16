// .vitepress/theme/index.js
import DefaultTheme from 'vitepress/theme';
import giscusTalk from 'vitepress-plugin-comment-with-giscus';
import { useData, useRoute } from 'vitepress';

export default {
    ...DefaultTheme,
    enhanceApp(ctx) {
        DefaultTheme.enhanceApp(ctx);
    },
    setup() {
        // Get frontmatter and route
        const { frontmatter } = useData();
        const route = useRoute();
        
        // Obtain configuration from: https://giscus.app/
        giscusTalk({
            repo: 'learnzig/learnzig',
            repoId: 'R_kgDOKRsb5Q',
            category: 'Comments', // default: `General`
            categoryId: 'DIC_kwDOKRsb5c4Cbx2i',
            mapping: 'pathname', // default: `pathname`
            inputPosition: 'top', // default: `top`
            lang: 'zh-CN', // default: `zh-CN`
            strict: "1",
            reactionsEnabled: "1",
            theme: "preferred_color_scheme",
        }, {
            frontmatter, route
        },
            true
        );
    }
};